# AWS MVP Infrastructure Baseline

This checklist records non-negotiable Security/SRE invariants for the sole active platform target.
A configured control counts as exercised only after approved live evidence is retained.

For the app/platform boundary, platform contract, and ownership model, see [docs/overview.md](overview.md).

## Invariants

| Invariant | Primary evidence |
| --- | --- |
| EC2 requires IMDSv2 and encrypted EBS | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| PostgreSQL backups use encrypted, versioned S3 storage with retention | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| Network ingress and egress are explicitly bounded | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| IAM permissions are resource-scoped where AWS supports it | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| Real backend, variable, state, credential, and secret values stay outside Git | [`aws-dev/`](../../terraform/environments/aws-dev/) |
| Checkov exceptions remain narrow and reviewed | [`TERRAFORM_CHECKS.md`](../../TERRAFORM_CHECKS.md) |

Static CI, a Terraform plan, or a written runbook is configuration evidence only. Provisioning,
deployment, rollback, recovery, and teardown claims require approved live target records.
