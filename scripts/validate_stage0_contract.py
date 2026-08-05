"""Validate the GitOps-ready Stage 0 app/infra boundary."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "environments/aws-dev/images.lock.json"
COMPOSE = ROOT / "deployment/aws-stage0/docker-compose.yml"
TERRAFORM = ROOT / "terraform/environments/aws-dev/main.tf"
WORKFLOW = ROOT / ".github/workflows/deploy-aws-stage0.yml"
ROLLOUT = ROOT / "deployment/aws-stage0/rollout.sh"
PYTHON_VERSION = ROOT / ".python-version"
SHA = re.compile(r"^[0-9a-f]{40}$")
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
PYTHON_MINOR = re.compile(r"^\d+\.\d+$")
PLACEHOLDER_SHA = "0" * 40
PLACEHOLDER_DIGEST = f"sha256:{'0' * 64}"
EXPECTED_CONTRACT = {
    "ingestor": (8000, "/health", "/readyz"),
    "inference": (8001, "/health", "/readyz"),
    "dashboard": (8501, "/_stcore/health", "/_stcore/health"),
}
EXPECTED_DEPENDENCY_IMAGES = {
    "pgvector/pgvector:pg17-trixie",
    "prom/prometheus:v2.54.1",
    "redpandadata/redpanda:v24.1.1",
    "redis:7-alpine",
}


def git_revision(app_root: Path, revision: str) -> str:
    """Resolve a Git revision in the checked-out application repository."""
    result = subprocess.run(
        ["git", "-C", str(app_root), "rev-parse", revision],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def selected_python_minor(path: Path) -> str | None:
    """Return a valid major.minor selector from a .python-version file."""
    if not path.is_file():
        return None
    version = path.read_text(encoding="utf-8").strip()
    return version if PYTHON_MINOR.fullmatch(version) else None


def validate(app_root: Path, *, allow_placeholder_lock: bool = False) -> list[str]:
    errors: list[str] = []
    manifest_path = app_root / "release/services.json"
    if not manifest_path.is_file():
        return ["app release/services.json is missing"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    app_python = selected_python_minor(app_root / ".python-version")
    infra_python = selected_python_minor(PYTHON_VERSION)
    if app_python is None:
        errors.append("app .python-version must contain a major.minor selector")
    if infra_python is None:
        errors.append("infra .python-version must contain a major.minor selector")
    if app_python and infra_python and app_python != infra_python:
        errors.append("app and infra .python-version values must match")
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    compose = COMPOSE.read_text(encoding="utf-8")
    terraform = TERRAFORM.read_text(encoding="utf-8")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    rollout = ROLLOUT.read_text(encoding="utf-8")
    manifest_services = manifest.get("services", [])
    services = {service["name"] for service in manifest_services}
    expected = set(EXPECTED_CONTRACT)
    if services != expected:
        errors.append("app release manifest service set is invalid")
    for service in manifest_services:
        name = service.get("name")
        if name not in EXPECTED_CONTRACT:
            continue
        port, health_path, readiness_path = EXPECTED_CONTRACT[name]
        if (
            service.get("port"),
            service.get("health_path"),
            service.get("readiness_path"),
        ) != (port, health_path, readiness_path):
            errors.append(f"{name}: app port or health contract is invalid")
    source_commit_sha = lock.get("source_commit_sha", "")
    source_tree_sha = lock.get("source_tree_sha", "")
    if lock.get("schema_version") != 1:
        errors.append("image lock schema version must be 1")
    for field, value in (
        ("source_commit_sha", source_commit_sha),
        ("source_tree_sha", source_tree_sha),
    ):
        if not SHA.fullmatch(value):
            errors.append(f"image lock must contain a full {field}")
        elif value == PLACEHOLDER_SHA and not allow_placeholder_lock:
            errors.append(f"image lock contains a placeholder {field}")
    if source_commit_sha != PLACEHOLDER_SHA and source_tree_sha != PLACEHOLDER_SHA:
        try:
            checked_out_commit = git_revision(app_root, "HEAD")
            checked_out_tree = git_revision(app_root, "HEAD^{tree}")
        except subprocess.CalledProcessError:
            errors.append("app root must be the exact checked-out Git repository")
        else:
            if checked_out_commit != source_commit_sha:
                errors.append("checked-out app commit does not match the image lock")
            if checked_out_tree != source_tree_sha:
                errors.append("checked-out app tree does not match the image lock")
    if set(lock.get("images", [])) != expected:
        errors.append("image lock must select every deployable service")
    for name in expected:
        image = lock.get("images", {}).get(name, {})
        digest = image.get("digest", "")
        if image.get("repository") != f"api-observatory/{name}" or not DIGEST.fullmatch(
            digest
        ):
            errors.append(f"{name}: invalid desired image reference")
        elif digest == PLACEHOLDER_DIGEST and not allow_placeholder_lock:
            errors.append(f"{name}: image lock contains a placeholder digest")
        if f"${{{name.upper()}_IMAGE:" not in compose:
            errors.append(f"{name}: Compose does not consume desired image state")
        port, _health_path, readiness_path = EXPECTED_CONTRACT[name]
        if f"127.0.0.1:{port}:{port}" not in compose:
            errors.append(
                f"{name}: Compose loopback port does not match the app contract"
            )
        if readiness_path not in compose:
            errors.append(
                f"{name}: Compose readiness path does not match the app contract"
            )
    for profile in lock.get("enabled_profiles", []):
        if profile not in {"inference", "cache", "broker", "monitoring"}:
            errors.append(f"unsupported optional profile: {profile}")
    for image in EXPECTED_DEPENDENCY_IMAGES:
        pinned_image = re.compile(rf"image:\s+{re.escape(image)}@sha256:[0-9a-f]{{64}}")
        if not pinned_image.search(compose):
            errors.append(f"Stage 0 dependency image is not pinned by digest: {image}")
    for marker in (
        "source_commit_sha",
        "enabled_profiles",
        "ENABLED_PROFILES",
        "concurrency:",
    ):
        if marker not in workflow:
            errors.append(f"deployment workflow is missing: {marker}")
    for marker in ("configure_profiles", "profile_enabled inference", "compose up -d"):
        if marker not in rollout:
            errors.append(f"rollout does not apply desired profiles: {marker}")
    for marker in (
        "github_actions_image_publish",
        "github_actions_infra_deploy",
        "aws_s3_bucket",
    ):
        if marker not in terraform:
            errors.append(f"Terraform must own {marker}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-root", required=True, type=Path)
    parser.add_argument(
        "--allow-placeholder-lock",
        action="store_true",
        help="Validate the pre-provisioning placeholder lock without allowing it to deploy.",
    )
    args = parser.parse_args()
    errors = validate(args.app_root, allow_placeholder_lock=args.allow_placeholder_lock)
    if errors:
        print(*errors, sep="\n", file=sys.stderr)
        return 1
    print("Stage 0 app/infra boundary is valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
