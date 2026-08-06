from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from scripts import promote_stage0_images


def release_metadata() -> dict[str, object]:
    return {
        "schema_version": 1,
        "source_repository": "ivanprytula/api-observatory",
        "source_commit_sha": "1" * 40,
        "source_tree_sha": "2" * 40,
        "images": {
            name: {
                "repository": f"api-observatory/{name}",
                "digest": f"sha256:{value * 64}",
            }
            for name, value in (
                ("ingestor", "3"),
                ("inference", "4"),
                ("dashboard", "5"),
            )
        },
    }


class PromoteStage0ImagesTests(unittest.TestCase):
    def test_valid_metadata_builds_lock_and_preserves_profiles(self) -> None:
        metadata = release_metadata()
        lock = promote_stage0_images.build_lock(
            metadata, {"enabled_profiles": ["inference"]}
        )

        self.assertEqual(promote_stage0_images.validate_metadata(metadata), [])
        self.assertEqual(lock["source_commit_sha"], "1" * 40)
        self.assertEqual(lock["enabled_profiles"], ["inference"])

    def test_missing_service_is_rejected(self) -> None:
        metadata = release_metadata()
        del metadata["images"]["dashboard"]  # type: ignore[index]

        self.assertIn(
            "release metadata must contain exactly three deployable images",
            promote_stage0_images.validate_metadata(metadata),
        )

    def test_placeholder_identity_and_digest_are_rejected(self) -> None:
        metadata = release_metadata()
        metadata["source_tree_sha"] = "0" * 40
        metadata["images"]["ingestor"]["digest"] = f"sha256:{'0' * 64}"  # type: ignore[index]

        errors = promote_stage0_images.validate_metadata(metadata)

        self.assertIn("source_tree_sha must be a non-placeholder full SHA", errors)
        self.assertIn(
            "ingestor: digest must be a non-placeholder sha256 digest", errors
        )

    def test_write_lock_replaces_json_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            lock_path = Path(directory) / "images.lock.json"
            lock_path.write_text('{"enabled_profiles": []}\n', encoding="utf-8")
            expected = promote_stage0_images.build_lock(
                release_metadata(), {"enabled_profiles": []}
            )

            promote_stage0_images.write_lock(lock_path, expected)

            self.assertEqual(
                json.loads(lock_path.read_text(encoding="utf-8")), expected
            )

    def test_unsupported_profile_is_rejected_before_promotion(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported or duplicate profiles"):
            promote_stage0_images.build_lock(
                release_metadata(), {"enabled_profiles": ["unknown"]}
            )

    def test_duplicate_release_builds_identical_desired_state(self) -> None:
        metadata = release_metadata()
        current = {"enabled_profiles": ["inference"]}

        first = promote_stage0_images.build_lock(metadata, current)
        duplicate = promote_stage0_images.build_lock(metadata, first)

        self.assertEqual(duplicate, first)

    def test_newer_release_supersedes_images_and_preserves_profiles(self) -> None:
        current = promote_stage0_images.build_lock(
            release_metadata(), {"enabled_profiles": ["inference", "monitoring"]}
        )
        newer = release_metadata()
        newer["source_commit_sha"] = "6" * 40
        newer["source_tree_sha"] = "7" * 40
        newer["images"] = {
            name: {
                "repository": f"api-observatory/{name}",
                "digest": f"sha256:{value * 64}",
            }
            for name, value in (
                ("ingestor", "8"),
                ("inference", "9"),
                ("dashboard", "a"),
            )
        }

        promoted = promote_stage0_images.build_lock(newer, current)

        self.assertEqual(promoted["source_commit_sha"], "6" * 40)
        self.assertEqual(promoted["source_tree_sha"], "7" * 40)
        self.assertEqual(promoted["enabled_profiles"], current["enabled_profiles"])
        self.assertNotEqual(promoted["images"], current["images"])


if __name__ == "__main__":
    unittest.main()
