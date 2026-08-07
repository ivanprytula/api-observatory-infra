# AWS MVP Platform Deployment Guide

This repository provisions and bootstraps the AWS MVP platform. It does not contain application
image locks, Compose files, or workload deployment workflows. The application repository owns the
reviewed desired state and sends it to this platform through SSM after a lock PR merges.

`mvp` describes the present product/deployment scope. `aws-dev` is the only active environment. Do
not add stage or production environment scaffolding before the EC2 exercise has retained deployment,
recovery, rollback, and teardown evidence.

## Platform Contract 1

Ansible bootstrap supplies the following host contract before app deployment can be enabled:

| Capability | Platform responsibility |
| --- | --- |
| Host path | `/opt/api-observatory-mvp` and root-protected `.runtime` directory |
| Runtime | Docker Engine and Docker Compose |
| Remote access | SSM with no inbound SSH requirement |
| Runtime values | `api-observatory-mvp-render-env <group>...` reads `/api-observatory/aws-dev/runtime/<group>` |
| Contract marker | `/opt/api-observatory-mvp/.platform-contract-version` contains `1` |
| Recovery | Host replacement, encrypted backup storage, and disposable restore tooling |

The app selects renderer groups from its reviewed profiles. Parameter Store implementation, EC2
replacement, backup storage, and infrastructure monitoring remain platform concerns. No secret value
is committed to Terraform, Ansible, or workflow configuration.

## Preparation and Bootstrap

Terraform state and live resources may contain sensitive metadata. Before any apply or physical-name
rename, inspect the selected state through the approved operator workflow and add reviewed `moved`
blocks or a migration plan when retained resources exist. This repository change is only
pre-provisioning configuration; it proves no live AWS state.

After separately approving the AWS account, state backend, and Terraform plan, bootstrap the host
from `ansible/`. First run check mode:

```bash
ansible-playbook -i inventory/hosts.yml --limit aws_dev \
  -e "ansible_host=$(terraform -chdir=../terraform/environments/aws-dev output -raw instance_id)" \
  -e "ansible_aws_ssm_bucket_name=$(terraform -chdir=../terraform/environments/aws-dev output -raw mvp_ansible_transfer_bucket)" \
  --check --diff \
  playbooks/bootstrap-aws-mvp.yml
```

After reviewing that output and obtaining approval, rerun without `--check --diff`. The controller
needs `session-manager-plugin` and scoped access to the short-lived Ansible transfer bucket. The
instance needs no SSH key or inbound port 22.

## Cutover Handoff

After the platform is applied and bootstrapped, give the app team these Terraform outputs through the
approved GitHub-environment setup process:

| App variable | Terraform output |
| --- | --- |
| `AWS_ECR_REGISTRY` | `ecr_registry` |
| `AWS_ECR_PUBLISH_ROLE_ARN` | `github_actions_image_publish_role_arn` |
| `AWS_APP_DEPLOY_ROLE_ARN` | `github_actions_app_deploy_role_arn` |
| `AWS_EC2_INSTANCE_ID_DEV` | `instance_id` |

Keep `AWS_IMAGE_PUBLISH_ENABLED` and `AWS_CD_ENABLED` disabled until this handoff is complete. The
app [OIDC setup](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/github-secrets-setup.md)
and [delivery contract](https://github.com/ivanprytula/api-observatory/blob/main/docs/07-deployment/app-repo-contract.md)
then govern promotion, deployment, application rollback, migrations, readiness, and smoke checks.

## Platform Recovery

The platform installs `api-observatory-mvp-backup-postgres` and
`api-observatory-mvp-restore-postgres`. Restore only into a named disposable database, verify it, and
retain redacted evidence before considering any recovery action. Application lock reverts are
application-image rollbacks; do not automate database downgrade migrations. Host replacement,
infrastructure rollback, backup storage, and restore tooling remain platform-owned.

Configuration and static checks are not evidence of a successful AWS deployment. The first approved
live run must retain redacted image, migration, readiness, smoke, rollback, backup/restore, and
teardown evidence.
