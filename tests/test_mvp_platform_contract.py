from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TERRAFORM = ROOT / "terraform/environments/aws-dev"
MVP_ROLE = ROOT / "ansible/roles/mvp"


class MvpPlatformContractTests(unittest.TestCase):
    def test_repository_has_one_active_aws_platform(self) -> None:
        environments = ROOT / "terraform/environments"

        self.assertEqual(
            {path.name for path in environments.iterdir() if path.is_dir()},
            {"aws-dev"},
        )
        self.assertFalse((ROOT / "kubernetes").exists())
        self.assertFalse((ROOT / "monitoring").exists())

    def test_app_deployment_role_is_limited_to_the_app_aws_dev_environment(
        self,
    ) -> None:
        terraform = (TERRAFORM / "main.tf").read_text(encoding="utf-8")
        outputs = (TERRAFORM / "outputs.tf").read_text(encoding="utf-8")

        self.assertIn('"github_actions_app_deploy_assume"', terraform)
        self.assertIn(
            "repo:${var.app_github_repository}:environment:aws-dev", terraform
        )
        self.assertIn('"github_actions_app_deploy"', terraform)
        self.assertIn("${var.project}-github-actions-app-deploy", terraform)
        self.assertIn('actions   = ["ecr:DescribeImages"]', terraform)
        self.assertIn('actions = ["ssm:SendCommand"]', terraform)
        self.assertIn('actions   = ["ssm:GetCommandInvocation"]', terraform)
        self.assertNotIn("infra_github_" + "repository", terraform)
        self.assertIn('output "github_actions_app_deploy_role_arn"', outputs)

    def test_platform_contract_installs_group_driven_renderer_and_marker(self) -> None:
        tasks = (MVP_ROLE / "tasks/main.yml").read_text(encoding="utf-8")
        renderer = (MVP_ROLE / "templates/render-mvp-env.sh.j2").read_text(
            encoding="utf-8"
        )

        self.assertIn(".platform-contract-version", tasks)
        self.assertIn("api-observatory-mvp-render-env", tasks)
        self.assertIn("api-observatory-mvp-backup-postgres", tasks)
        self.assertIn("api-observatory-mvp-restore-postgres", tasks)
        self.assertIn("Usage: api-observatory-mvp-render-env <group>...", renderer)
        self.assertIn('for group in "$@"', renderer)
        self.assertIn("render_group_env", renderer)
        self.assertNotIn("render_service_env ingestor", renderer)

    def test_infra_ci_has_no_application_desired_state_or_deployment_path(self) -> None:
        ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")

        self.assertNotIn("images.lock.json", ci)
        self.assertNotIn("deploy-aws-mvp", ci)
        self.assertNotIn("actions/configure-aws-credentials", ci)
        self.assertNotIn("id-token: write", ci)
        self.assertFalse((ROOT / "deployment/aws-" / ("stage" + "0")).exists())
        self.assertFalse((ROOT / "environments/aws-dev/images.lock.json").exists())


if __name__ == "__main__":
    unittest.main()
