# AWS MVP Infrastructure Baseline

This checklist records invariants for the sole active platform target. A configured control counts
as exercised only after approved live evidence is retained.

## Platform

| Invariant | Primary evidence |
| --- | --- |
| EC2 requires IMDSv2 and encrypted EBS | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| PostgreSQL backups use encrypted, versioned S3 storage with retention | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| Network ingress and egress are explicitly bounded | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| IAM permissions are resource-scoped where AWS supports it | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| Real backend, variable, state, credential, and secret values stay outside Git | [`aws-dev/`](../../terraform/environments/aws-dev/) |
| Checkov exceptions remain narrow and reviewed | [`TERRAFORM_CHECKS.md`](../../TERRAFORM_CHECKS.md) |

## Delivery and Recovery

| Invariant | Primary evidence |
| --- | --- |
| Application images and environment interfaces follow the app-owned contract | [App delivery contract](https://github.com/ivanprytula/api-observatory/blob/main/docs/07-deployment/app-repo-contract.md) |
| GitHub and EC2 use separate short-lived roles; EC2 receives values through its SSM role | [CI/CD guide](../deployment/ci-cd-guide.md) |
| Bootstrap installs the versioned host path, grouped renderer, and bounded backup/restore commands | [Deployment guide](../deployment/deployment-guide.md) |
| App-owned Compose controls workload Prometheus configuration; AWS Terraform controls platform logs | [Observability guide](../operations/observability.md) |
| Restore is verified against an explicit disposable database before any promotion decision | [Recovery guide](../operations/recovery-guide.md) |

Static CI, a Terraform plan, or a written runbook is configuration evidence only. Provisioning,
deployment, rollback, recovery, and teardown claims require approved target records.
