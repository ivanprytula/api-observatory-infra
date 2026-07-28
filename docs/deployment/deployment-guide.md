# AWS Stage 0 Deployment Guide

AWS Stage 0 is the primary portfolio direction: three immutable ECR images on one EC2 Docker
Compose host backed by RDS PostgreSQL. Configuration and workflows exist, but no completed live
deployment is claimed.

Real provisioning, deployment, restore, and teardown mutate an account and may create cost. Review
the exact plan/targets and obtain explicit approval before running them. The
[`Justfile`](../../Justfile), Terraform, Ansible, and app workflows own command syntax.

## Ownership and Contract

- The app repository owns code, Dockerfiles, configuration names, ports, health behavior, and the
  [machine-readable service contract](https://github.com/ivanprytula/api-observatory/blob/main/infra/deployment/aws-stage0-services.json).
- This repository owns `aws-dev` Terraform, EC2/RDS/IAM/networking, Ansible host provisioning, and
  runtime secret delivery.
- The app [deployment contract](https://github.com/ivanprytula/api-observatory/blob/main/docs/07-deployment/app-repo-contract.md)
  is the human-readable boundary.

| Service | ECR repository suffix | Port | Health/readiness |
| --- | --- | ---: | --- |
| ingestor | `api-observatory/ingestor` | 8000 | `/health`, `/readyz` |
| inference | `api-observatory/inference` | 8001 | `/health`, `/readyz` |
| dashboard | `api-observatory/dashboard` | 8501 | `/_stcore/health` |

MCP remains a local stdio process and is not deployed.

## Preparation Gates

1. Validate all three images and the app/infra contract locally.
2. Review Terraform plan, Checkov exceptions, expected cost, state retention, and teardown.
3. Supply short-lived GitHub OIDC roles, ECR, EC2 instance role, and protected `aws-dev`
   environment. These identities are prerequisites; this repository does not currently create them.
4. Run the relevant Terraform/Ansible validation from their owning source before provisioning.
5. Provision only after approval and deliver runtime secrets outside repository/workflow files.

The app [OIDC setup](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/github-secrets-setup.md)
owns repository variables and least-privilege role responsibilities.

## Delivery and Verification

Routine app CI builds and health-checks images locally without AWS credentials or registry
publication. Manually triggered, CI-gated CD from `develop` or `main` uses GitHub OIDC to build and
push `tree-<SHA>` images to ECR, resolves their digests, and uses Systems Manager to deploy the
selected immutable references. Tag-based release promotion remains suspended until a live Stage 0
deploy, rollback, and teardown have been exercised.

Capture redacted evidence for the deployed image identity, health/readiness, migration result,
authenticated critical path, signal correlation, dependency recovery, and infrastructure state.
Configuration or a successful plan alone is not deployment proof.

## Rollback and Teardown

Rollback selects the previous immutable tree tag and repeats the same health/smoke gates. It is
unsafe after an incompatible schema contraction; review application and migration compatibility
together.

Before temporary deployment, identify every billable resource and retention decision. Teardown
requires a reviewed destroy plan and explicit destructive-action approval. Afterwards verify EC2,
RDS, ECR storage, public IPs, logs, KMS resources, and remote state against the intended retained
set. Stopping EC2 alone does not stop all cost.

Use [platform observability](../operations/observability.md) and the
[recovery guide](../operations/recovery-guide.md) for runtime evidence. Azure remains
secondary/reference and must not be mixed into the AWS Stage 0 claim.
