# API Observatory Infra — Overview

AWS-first Infrastructure-as-Code for the [API Observatory](https://github.com/ivanprytula/api-observatory) platform.

AWS is the only active infrastructure direction. The [evolution plan](./architecture/evolution-plan.md) owns platform stages and adoption triggers, while the [baseline checklist](./architecture/baseline-checklist.md) owns durable security/SRE controls.

## App / Platform Boundary

| Concern | This repository owns | Application repository owns |
| --- | --- | --- |
| Delivery | Terraform state, networking, ECR, one EC2 host with encrypted EBS, IAM, Parameter Store, Docker/SSM bootstrap, retained S3 backups, host recovery, AWS platform logs | Application CI, immutable images, the reviewed `aws-dev` lock, Compose workload, migrations, readiness, smoke checks, application rollback |
| CI/CD | Terraform + Ansible capabilities, static validation gates, OIDC role definitions | Image publication, same-repo desired-state promotion, SSM workload deployment, environment protection, `APP_PROMOTION_TOKEN` |
| Observability | AWS platform resources (VPC flow logs → encrypted CloudWatch, EC2/EBS/S3/ECR/IAM/SSM inspection) | Application metrics, health/readiness semantics, structured logs, traces, workload Prometheus configuration |
| Recovery | EC2 replacement/bootstrap, Parameter Store delivery, retained S3 backup storage, host-installed PostgreSQL backup/restore commands | Immutable workload desired state, migrations, readiness, smoke proof, application-image rollback |

When an interface changes, update the app delivery contract and the MVP platform contract together.

## Platform Contract

| Concern | Current choice |
| --- | --- |
| Compute | One EC2 host running app-owned Docker Compose desired state |
| Database | PostgreSQL containers on encrypted EC2 EBS |
| Images | App-published immutable ECR digests |
| Access | Systems Manager only; no inbound SSH or public application ingress |
| Runtime values | EC2 role reads grouped SecureString parameters from Parameter Store |
| Recovery | Retained S3 PostgreSQL backups and disposable restore verification |
| Delivery | Reviewed app lock merge triggers the app-owned deployment workflow |

## Static Validation vs. Live Evidence

CI, a Terraform plan, Ansible check mode, or a written runbook is configuration evidence only. Provisioning, deployment, rollback, recovery, and teardown claims require approved live target records. Do not describe a Terraform plan, OIDC role, static check, or published image as a completed deployment.

## Repository Structure

```text
terraform/
  environments/
    aws-dev/             AWS MVP platform environment
ansible/                 SSM inventory and AWS MVP host-bootstrap roles
scripts/                 Static validation and developer diagnostics
docs/                    CI, deployment, observability, recovery, evolution, baseline
```

## Related Documentation

| Document | Purpose |
| --- | --- |
| [Evolution plan](../docs/architecture/evolution-plan.md) | AWS learning sequence (EC2 → ECS/Fargate → EKS → another IaaS), current contract, stage entry triggers |
| [Baseline checklist](../docs/architecture/baseline-checklist.md) | Non-negotiable Security/SRE invariants for the sole active platform target |
| [Deployment guide](../docs/deployment/deployment-guide.md) | Bootstrap the AWS MVP platform and handoff outputs to the app repository |
| [CI/CD configuration guide](../docs/deployment/ci-cd-guide.md) | Platform OIDC roles, app GitHub environment wiring, promotion model |
| [Observability](../docs/operations/observability.md) | Current platform signals and verification requirements |
| [Recovery guide](../docs/operations/recovery-guide.md) | PostgreSQL backup/restore, host and workload recovery runbook |

## Prerequisites

| Work | Developer-machine dependencies |
| --- | --- |
| Application work or local Compose verification | Follow the app [Setup Guide](https://github.com/ivanprytula/api-observatory/blob/main/docs/04-setup/setup-guide.md); this repository does not duplicate its versions |
| Terraform formatting, validation, and plan review | Terraform and TFLint |
| Ansible playbook development and linting | `pipx`, full Ansible, `ansible-lint`, and collections from `ansible/requirements.yml` |
| AWS MVP bootstrap | AWS CLI, `session-manager-plugin`, Terraform, Ansible, `jq`, and S3-capable AWS credentials on the controller |
