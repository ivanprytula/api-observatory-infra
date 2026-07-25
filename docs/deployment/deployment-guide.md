# Deployment Guide — AWS Stage 0

AWS Stage 0 is the primary portfolio deployment direction: immutable ECR images deployed with
Docker Compose on one EC2 host, backed by RDS PostgreSQL. The configuration and workflows are
present, but no completed live deployment is claimed.

Real provisioning, deployment, and teardown are account mutations with possible cost. Review the
plan and budget controls and obtain explicit approval before running them.

## Ownership and Contract

- The app repository owns service code, Dockerfiles, environment names, ports, health behavior, and
  [`infra/deployment/aws-stage0-services.json`](https://github.com/ivanprytula/api-observatory/blob/main/infra/deployment/aws-stage0-services.json).
- This repository owns `terraform/environments/aws-dev/`, EC2/RDS/IAM/networking, Ansible host
  provisioning, and runtime secret delivery.
- The canonical human-readable boundary is the app repository's
  [deployment contract](https://github.com/ivanprytula/api-observatory/blob/main/docs/07-deployment/app-repo-contract.md).

## Deployable Services

| Service | ECR repository | Port | Health/readiness |
| --- | --- | ---: | --- |
| ingestor | `api-observatory/ingestor` | 8000 | `/health`, `/readyz` |
| inference | `api-observatory/inference` | 8001 | `/health`, `/readyz` |
| dashboard | `api-observatory/dashboard` | 8501 | `/_stcore/health` |

Images use `${AWS_ECR_REGISTRY}/api-observatory/<service>:tree-<SHA>`. The local stdio MCP server is
not a cloud service.

## Safe Preparation

1. Validate the app service contract and all three images locally.
2. Review the `aws-dev` Terraform plan, Checkov skips, estimated cost, and teardown procedure.
3. Configure an S3 backend and short-lived GitHub/AWS identities; do not use long-lived access keys.
4. Provision infrastructure only after approval.
5. Run the AWS Ansible playbook against the explicit `aws_dev` inventory target.
6. Configure GitHub environment protection before enabling application CD.

Example validation commands that do not apply infrastructure:

```bash
TF_ENV=aws-dev just tf fmt
TF_ENV=aws-dev just tf validate
TF_ENV=aws-dev just tf plan
just ansible-lint
```

Inspect the generated plan before any `apply`. Never store a real plan containing sensitive values
in the repository.

## Application Workflow Contract

The application repository's workflows are disabled unless the required repository variables exist:

- `AWS_ECR_REGISTRY`
- `AWS_REGION`
- `AWS_ROLE_ARN_CI`
- `AWS_ROLE_ARN_DEV`
- `AWS_ROLE_ARN_RELEASE`
- `AWS_EC2_INSTANCE_ID_DEV`

CI builds/scans immutable candidates after OIDC authentication. The protected `aws-dev` workflow
uses Systems Manager to pull the three `tree-<SHA>` images, restart only those services, and check
their health endpoints. Release promotion copies an existing candidate to a semantic version tag;
it does not publish `latest`.

## Verification and Rollback

After deployment, capture redacted evidence for:

1. the deployed `tree-<SHA>` version;
2. all health/readiness endpoints;
3. database connectivity and migrations;
4. one authenticated application smoke path;
5. metrics/log/trace correlation;
6. restart and dependency-recovery behavior.

Rollback must select the previous immutable tree tag and repeat the same health gates. A rollback is
unsafe if an incompatible database contraction has already executed; application and migration
compatibility must be reviewed together.

## Teardown

Before a temporary portfolio deployment, identify all expected billable resources and enable budget
alerts. After evidence collection:

1. preserve only intentionally retained, non-secret evidence;
2. inspect the exact Terraform workspace and plan the destroy;
3. obtain destructive-action approval;
4. destroy the explicit `aws-dev` resources;
5. verify that EC2, RDS, ECR storage, public IPs, logs, KMS resources, and remote-state resources match
   the intended retention decision.

Do not treat an EC2 stop operation as full cost teardown.

## Secondary Azure Reference

Azure Terraform and provisioning assets remain for comparison and foundational learning. They are
secondary/reference infrastructure and should not be mixed into the AWS Stage 0 deployment claim.
