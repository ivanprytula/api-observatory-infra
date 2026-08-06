# MVP Platform CI/CD Configuration Guide

Application CI/CD and platform CI have separate responsibilities. The app repository owns image
publication, same-repository desired-state promotion, and SSM workload deployment. This repository
owns the Terraform and Ansible capabilities that make those app workflows possible.

## Platform-Provided Identities

`terraform/environments/aws-dev/main.tf` defines two application-repository OIDC roles:

| Role output | GitHub environment | Least-privilege purpose |
| --- | --- | --- |
| `github_actions_image_publish_role_arn` | `aws-image-publish` | Push and inspect the three immutable ECR repositories |
| `github_actions_app_deploy_role_arn` | `aws-dev` | Inspect ECR digests and send/inspect SSM commands for the selected EC2 host |

Both trusts are restricted to `repo:ivanprytula/api-observatory` and their exact GitHub environment.
The EC2 role separately pulls images and reads the unchanged Parameter Store path
`/api-observatory/aws-dev/runtime`. No infrastructure-repository GitHub identity can deploy the
application workload.

## App Handoff

After a reviewed Terraform apply and Ansible bootstrap, configure app GitHub environments using the
outputs documented in the [platform deployment guide](deployment-guide.md). Keep
`AWS_IMAGE_PUBLISH_ENABLED` and `AWS_CD_ENABLED` false or unset during setup. Configure the app's
same-repository `APP_PROMOTION_TOKEN` there; this repository never stores or consumes that token.

Protect both repositories' `main` branches with pull requests and `CI / Merge gate`. Restrict the
app `aws-image-publish` and `aws-dev` environments to `main`; the reviewed app lock merge is the
routine approval, so extra environment-review prompts would duplicate it.

## Boundaries

Infra CI runs static Terraform, Ansible, workflow, documentation, and platform-contract checks. It
does not check out application source, create promotion PRs, assume application deployment
credentials, or send SSM workload commands. A passing check, Terraform plan, or provisioned role is
configuration evidence only, not proof of a working deployment.

Use the app [CI/CD reference](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/ci-cd.md)
for the executable delivery path and the app [OIDC setup](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/github-secrets-setup.md)
for GitHub variables and secret handling.
