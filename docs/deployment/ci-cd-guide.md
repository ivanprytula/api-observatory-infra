# CI/CD Configuration Guide

This guide maps the two-repository GitHub Actions wiring behind the AWS Stage 0 promotion flow.
It is a configuration checklist with links to the official GitHub documentation, not a behavior spec.
The promotion contract lives in [promotion-model.md](promotion-model.md); the end-to-end rollout
procedure lives in [deployment-guide.md](deployment-guide.md).

## Flow overview

1. App repo (`api-observatory`) builds immutable `tree-<SHA>` images, uploads release metadata, and
   sends a `repository_dispatch` event to the infra repo.
2. Infra repo (`api-observatory-infra`) promotes that metadata into `environments/aws-dev/images.lock.json`,
   commits it, and deploys the locked desired state to the EC2 host.

## Where each part is configured

| Component | Repository | Location |
| --- | --- | --- |
| Image publish workflow | app | `.github/workflows/publish-images.yml` |
| Cross-repo dispatch producer | app | `.github/workflows/publish-images.yml:88-115` |
| Deployment workflow | infra | `.github/workflows/deploy-aws-stage0.yml` |
| Infra OIDC deploy role | infra | `terraform/environments/aws-dev/main.tf` |
| App OIDC image-publish role | infra | `terraform/environments/aws-dev/main.tf` |
| Environment variables and secrets | both | GitHub UI or `gh` CLI |

## Events

- `repository_dispatch` carries the release payload from the app repo to the infra repo deployment
  workflow (`deploy-aws-stage0.yml:20-21`). The app repo sends it with a fine-grained PAT.
- `workflow_dispatch` starts the same infra deployment manually from the GitHub UI with
  `promotion_target` and `environment_name` inputs.
- Trigger reference: [Events that trigger workflows](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows).
- Manual dispatch reference: [Manually running a workflow](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manually-running-a-workflow).

## Environments

Environments are **per-repository**; they are not shared between the two repos.

| Repository | Environment | Used by | Purpose |
| --- | --- | --- | --- |
| app | `aws-image-publish` | `publish-images.yml` | OIDC role for ECR login and image push |
| infra | `aws-dev` | `deploy-aws-stage0.yml` | OIDC deploy role, env-scoped vars, deployment protection rules |

Environment-scoped values (`vars.*`) and secrets are visible only to jobs bound to the environment,
so the OIDC trust must match the environment name. The infra role trust is pinned to the
`repo:ivanprytula/api-observatory-infra:environment:aws-dev` subject
(`terraform/environments/aws-dev/main.tf:401-405`); the app role trust is pinned to
`repo:ivanprytula/api-observatory:environment:aws-image-publish`
(`terraform/environments/aws-dev/main.tf:355`).

References: [Managing environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments),
[Configuring OIDC in cloud providers](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-cloud-providers).

## Variables and secrets

- Repository variables store non-secret configuration: `AWS_REGION`, `AWS_ECR_REGISTRY`, role ARNs,
  instance ID, and the `AWS_*_ENABLED` gates.
- Environment secrets store credentials: `INFRA_PROMOTION_TOKEN` in the app repo's
  `aws-image-publish` environment.
- The app-side list of variables and their owners is documented in the app repository's
  [GitHub secrets setup](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/github-secrets-setup.md).
- References: [Using secrets in GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions),
  [Storing information in variables](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables).

## Cross-repo promotion token

The app workflow needs a token with permission to dispatch events into the infra repo. GitHub has no
API to create PATs, so this step is manual once, then scriptable afterwards:

1. In the GitHub UI, create a fine-grained PAT for the app account with read access to the app repo
   and read/write access to the infra repo (Actions and Contents permissions, or the minimal set the
   dispatch API needs).
2. Store it once with `gh secret set INFRA_PROMOTION_TOKEN --repo ivanprytula/api-observatory
   --env aws-image-publish`.
3. Reference: [Managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

## Pending values after Terraform apply

The publish and deploy gates stay `false`/empty until a real apply supplies these values:

| Variable | Repository | Value from |
| --- | --- | --- |
| `AWS_ECR_REGISTRY` | app | infra `terraform output ecr_registry` |
| `AWS_ECR_PUBLISH_ROLE_ARN` | app | infra `terraform output github_actions_image_publish_role_arn` |
| `AWS_INFRA_DEPLOY_ROLE_ARN` | infra | infra `terraform output github_actions_infra_deploy_role_arn` |
| `AWS_EC2_INSTANCE_ID_DEV` | infra | infra `terraform output instance_id` |

Set the `AWS_*_ENABLED` gates to `true` only after a test publish and deploy are green.

## Go-live checklist

1. Bootstrap the state backend and apply `aws-dev` Terraform (see
   [deployment-guide.md](deployment-guide.md)).
2. Fill the pending variables from `terraform output` and verify each role's OIDC subject matches its
   environment.
3. Publish a CI-green image set manually and confirm the infra promotion commit lands.
4. Run one full deploy, verify health/readiness evidence, then set `AWS_IMAGE_PUBLISH_ENABLED=true`.
