"""Validate the GitOps-ready Stage 0 app/infra boundary."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "environments/aws-dev/images.lock.json"
COMPOSE = ROOT / "deployment/aws-stage0/docker-compose.yml"
TERRAFORM = ROOT / "terraform/environments/aws-dev/main.tf"
WORKFLOW = ROOT / ".github/workflows/deploy-aws-stage0.yml"
ROLLOUT = ROOT / "deployment/aws-stage0/rollout.sh"
SHA = re.compile(r"^[0-9a-f]{40}$")
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
PLACEHOLDER_SHA = "0" * 40
PLACEHOLDER_DIGEST = f"sha256:{'0' * 64}"


def validate(app_root: Path, *, allow_placeholder_lock: bool = False) -> list[str]:
    errors: list[str] = []
    manifest_path = app_root / "release/services.json"
    if not manifest_path.is_file():
        return ["app release/services.json is missing"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    compose = COMPOSE.read_text(encoding="utf-8")
    terraform = TERRAFORM.read_text(encoding="utf-8")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    rollout = ROLLOUT.read_text(encoding="utf-8")
    services = {service["name"] for service in manifest.get("services", [])}
    expected = {"ingestor", "inference", "dashboard"}
    if services != expected:
        errors.append("app release manifest service set is invalid")
    source_tree_sha = lock.get("source_tree_sha", "")
    if lock.get("schema_version") != 1 or not SHA.fullmatch(source_tree_sha):
        errors.append("image lock must contain schema version 1 and a full tree SHA")
    elif source_tree_sha == PLACEHOLDER_SHA and not allow_placeholder_lock:
        errors.append(
            "image lock contains a placeholder tree SHA; promote published images before deployment"
        )
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
    for profile in lock.get("enabled_profiles", []):
        if profile not in {"inference", "cache", "broker", "monitoring"}:
            errors.append(f"unsupported optional profile: {profile}")
    for marker in ("enabled_profiles", "ENABLED_PROFILES", "concurrency:"):
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
