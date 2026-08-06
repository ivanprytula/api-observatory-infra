# CI/CD Configuration Guide

This guide maps the two-repository GitHub Actions wiring behind the AWS Stage 0 promotion flow.
It is a configuration checklist with links to the official GitHub documentation, not a behavior spec.
The promotion contract lives in [promotion-model.md](promotion-model.md); the end-to-end rollout
procedure lives in [deployment-guide.md](deployment-guide.md).

## Flow overview

1. A deployable app `main` change passes `CI / Merge gate`, then calls the reusable publisher to
   build immutable `tree-<SHA>` images.
2. The publisher checks out current infra `main`, runs its promotion script, and uses a pinned PR
   action to open or update `automation/promote-aws-dev` with the `images.lock.json` change.
3. Merging that green PR approves the release. Infra `main` CI calls the deployment workflow to
   apply the exact merged desired state to the EC2 host.

## Where each part is configured

| Component | Repository | Location |
| --- | --- | --- |
| Image publish workflow | app | `.github/workflows/publish-images.yml` |
| Promotion logic | infra | `scripts/promote_stage0_images.py` |
| Deployment workflow | infra | `.github/workflows/deploy-aws-stage0.yml` |
| Infra OIDC deploy role | infra | `terraform/environments/aws-dev/main.tf` |
| App OIDC image-publish role | infra | `terraform/environments/aws-dev/main.tf` |
| Environment variables and secrets | both | GitHub UI or `gh` CLI |

## Events

- `workflow_call` lets app CI invoke image publication only after a deployable `main` change passes
  its merge gate. Manual `workflow_dispatch` remains available for an initial release or retry.
- The same publisher uses the scoped PAT only to check out infra `main` and update its fixed lock PR.
  It cannot deploy because deployment accepts only a green lock already merged to infra `main`.
- Infra CI invokes deployment through `workflow_call` only after a merged `aws-dev` lock change
  passes the infra merge gate. Manual `workflow_dispatch` replays current infra `main`; it accepts no
  image, lane, or environment input.
- Trigger reference: [Events that trigger workflows](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows).
- Manual dispatch reference: [Manually running a workflow](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manually-running-a-workflow).

## Environments

Environments are **per-repository**; they are not shared between the two repos.

| Repository | Environment | Used by | Purpose |
| --- | --- | --- | --- |
| app | `aws-image-publish` | `publish-images.yml` | OIDC role for ECR login and image push |
| infra | `aws-dev` | `deploy-aws-stage0.yml` | OIDC deploy role, env-scoped vars, `main` restriction |

Environment-scoped values (`vars.*`) and secrets are visible only to jobs bound to the environment,
so the OIDC trust must match the environment name. The infra role trust is pinned to the
`repo:ivanprytula/api-observatory-infra:environment:aws-dev` subject
(`terraform/environments/aws-dev/main.tf:401-405`); the app role trust is pinned to
`repo:ivanprytula/api-observatory:environment:aws-image-publish`
(`terraform/environments/aws-dev/main.tf:355`).

Restrict both environments to `main`. Do not add routine required-reviewer prompts: the reviewed
promotion PR merge is the human approval. Before enabling either AWS gate, require pull requests and
`CI / Merge gate` on both repositories' `main` branches.

References: [Managing environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments),
[Configuring OIDC in cloud providers](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-cloud-providers).

## Variables and secrets

- Repository variables store non-secret configuration: `AWS_REGION`, `AWS_ECR_REGISTRY`, role ARNs,
  instance ID, and the `AWS_*_ENABLED` gates.
- The app `aws-image-publish` environment stores `INFRA_PROMOTION_TOKEN`.
- The app-side list of variables and their owners is documented in the app repository's
  [GitHub secrets setup](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/github-secrets-setup.md).
- References: [Using secrets in GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions),
  [Storing information in variables](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables).

## Cross-repo promotion token

The app workflow needs a token to check out the infra repository, push the dedicated bot branch, and
maintain its PR. A normal workflow `GITHUB_TOKEN` cannot write to the sibling repository or trigger
its pull-request CI. See
[GitHub token behavior](https://docs.github.com/en/actions/concepts/security/github_token).

GitHub has no API to create PATs, so token creation is a one-time manual operation:

1. Create an expiring fine-grained PAT scoped only to `ivanprytula/api-observatory-infra`, with
   Contents and Pull requests read/write access.
2. Store it in the app's `aws-image-publish` environment with
   `gh secret set INFRA_PROMOTION_TOKEN --repo ivanprytula/api-observatory --env aws-image-publish`.
3. Record the expiry privately and rotate the stored value. Never pass the token as a
   command argument or store it in repository variables.
4. Reference: [Managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

## Pending values after Terraform apply

The publish and deploy gates stay `false`/empty until a real apply supplies these values:

| Variable | Repository | Value from |
| --- | --- | --- |
| `AWS_ECR_REGISTRY` | app | infra `terraform output ecr_registry` |
| `AWS_ECR_PUBLISH_ROLE_ARN` | app | infra `terraform output github_actions_image_publish_role_arn` |
| `AWS_INFRA_DEPLOY_ROLE_ARN` | infra | infra `terraform output github_actions_infra_deploy_role_arn` |
| `AWS_EC2_INSTANCE_ID_DEV` | infra | infra `terraform output instance_id` |

Keep both `AWS_*_ENABLED` gates false or unset while repository automation is being configured.

## Go-live checklist

1. Bootstrap the state backend and apply `aws-dev` Terraform (see
   [deployment-guide.md](deployment-guide.md)).
2. Fill the pending variables from `terraform output` and verify each role's OIDC subject matches its
   environment.
3. Configure the scoped promotion token, protect both `main` branches, and restrict the AWS
   environments to `main` without an extra routine reviewer prompt.
4. For the approved first run, enable image publication and deployment, then manually publish a
   CI-green `main` release if there is no new deployable merge available.
5. Confirm that the bot opens the promotion PR and does not deploy before merge. Review its exact
   lock and CI results, then merge it to start deployment.
6. Retain redacted image, migration, readiness, smoke, rollback, and teardown evidence. A workflow
   configuration or green static check is not live-deployment proof.
