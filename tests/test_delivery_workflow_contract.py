from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github/workflows"


class DeliveryWorkflowContractTests(unittest.TestCase):
    def test_deployment_reads_only_committed_desired_state(self) -> None:
        deployment = (WORKFLOWS / "deploy-aws-stage0.yml").read_text(encoding="utf-8")

        self.assertIn("workflow_call:", deployment)
        self.assertIn("workflow_dispatch:", deployment)
        self.assertIn("contents: read", deployment)
        self.assertIn("vars.AWS_CD_ENABLED == 'true'", deployment)
        self.assertIn(
            "environments/${TARGET_ENVIRONMENT_NAME}/images.lock.json", deployment
        )
        self.assertIn("aws ssm send-command", deployment)
        self.assertNotIn("repository_dispatch:", deployment)
        self.assertNotIn("github.event.client_payload", deployment)
        self.assertNotIn("contents: write", deployment)
        self.assertNotIn("scripts/promote_stage0_images.py", deployment)
        self.assertNotIn("git commit", deployment)
        self.assertNotIn("git push", deployment)
        self.assertIn(".images | to_entries[]", deployment)
        self.assertNotIn("for service in ingestor inference dashboard", deployment)

    def test_infra_ci_deploys_only_green_merged_lock_changes_and_reverts(self) -> None:
        ci = (WORKFLOWS / "ci.yml").read_text(encoding="utf-8")

        self.assertIn("aws_stage0_lock:", ci)
        self.assertIn("grep -Fxq 'environments/aws-dev/images.lock.json'", ci)
        self.assertIn("needs: [changes, merge-gate]", ci)
        self.assertIn("github.event_name == 'push'", ci)
        self.assertIn("needs.changes.outputs.aws_stage0_lock == 'true'", ci)
        self.assertIn("uses: ./.github/workflows/deploy-aws-stage0.yml", ci)
        self.assertEqual(ci.count("uses: ./.github/workflows/deploy-aws-stage0.yml"), 1)


if __name__ == "__main__":
    unittest.main()
