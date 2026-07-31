from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import validate_stage0_contract


def manifest() -> dict[str, object]:
    return {
        "schema_version": 1,
        "services": [
            {
                "name": name,
                "port": port,
                "health_path": health,
                "readiness_path": ready,
            }
            for name, (port, health, ready) in (
                ("ingestor", (8000, "/health", "/readyz")),
                ("inference", (8001, "/health", "/readyz")),
                ("dashboard", (8501, "/_stcore/health", "/_stcore/health")),
            )
        ],
    }


class ValidateStage0ContractTests(unittest.TestCase):
    def make_app_repo(self, root: Path) -> tuple[str, str]:
        release = root / "release"
        release.mkdir()
        (release / "services.json").write_text(json.dumps(manifest()), encoding="utf-8")
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        subprocess.run(
            ["git", "-C", str(root), "config", "user.email", "test@example.com"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(root), "config", "user.name", "Contract Test"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(root), "add", "release/services.json"], check=True
        )
        subprocess.run(
            ["git", "-C", str(root), "commit", "-qm", "test contract"], check=True
        )
        commit = validate_stage0_contract.git_revision(root, "HEAD")
        tree = validate_stage0_contract.git_revision(root, "HEAD^{tree}")
        return commit, tree

    def write_lock(self, path: Path, commit: str, tree: str) -> None:
        path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "source_commit_sha": commit,
                    "source_tree_sha": tree,
                    "enabled_profiles": [],
                    "images": {
                        name: {
                            "repository": f"api-observatory/{name}",
                            "digest": f"sha256:{value * 64}",
                        }
                        for name, value in (
                            ("ingestor", "1"),
                            ("inference", "2"),
                            ("dashboard", "3"),
                        )
                    },
                }
            ),
            encoding="utf-8",
        )

    def test_exact_app_commit_and_tree_are_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "app"
            root.mkdir()
            commit, tree = self.make_app_repo(root)
            lock = Path(directory) / "images.lock.json"
            self.write_lock(lock, commit, tree)

            with patch.object(validate_stage0_contract, "LOCK", lock):
                errors = validate_stage0_contract.validate(root)

            self.assertEqual(errors, [])

    def test_mismatched_commit_and_tree_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "app"
            root.mkdir()
            self.make_app_repo(root)
            lock = Path(directory) / "images.lock.json"
            self.write_lock(lock, "a" * 40, "b" * 40)

            with patch.object(validate_stage0_contract, "LOCK", lock):
                errors = validate_stage0_contract.validate(root)

            self.assertIn(
                "checked-out app commit does not match the image lock", errors
            )
            self.assertIn("checked-out app tree does not match the image lock", errors)

    def test_placeholder_lock_requires_explicit_fixture_mode(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "app"
            root.mkdir()
            self.make_app_repo(root)
            lock = Path(directory) / "images.lock.json"
            self.write_lock(lock, "0" * 40, "0" * 40)

            with patch.object(validate_stage0_contract, "LOCK", lock):
                strict_errors = validate_stage0_contract.validate(root)
                fixture_errors = validate_stage0_contract.validate(
                    root, allow_placeholder_lock=True
                )

            self.assertTrue(any("placeholder" in error for error in strict_errors))
            self.assertEqual(fixture_errors, [])


if __name__ == "__main__":
    unittest.main()
