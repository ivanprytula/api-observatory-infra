# Infrastructure Baseline

This checklist records durable infrastructure invariants. It is not a completion claim: a control
counts as exercised only when the corresponding validation or deployment evidence has been
retained. The [evolution plan](evolution-plan.md) owns adoption triggers.

## AWS Stage 0

| Invariant | Primary evidence |
| --- | --- |
| EC2 requires IMDSv2 and encrypted storage | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| PostgreSQL data uses encrypted EC2 EBS volumes; encrypted, versioned S3 backup artifacts have retained lifecycle rules | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| Network ingress and egress are explicitly bounded | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| IAM permissions use resource-scoped policies where the resource is known | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| Logs and monitoring resources are encrypted where configured | [`aws-dev/main.tf`](../../terraform/environments/aws-dev/main.tf) |
| Real values stay outside Git; only example variable/backend files are committed | [`terraform/environments/aws-dev/`](../../terraform/environments/aws-dev/) |

Terraform, TFLint, and Checkov validation are owned by the
[infrastructure CI workflow](../../.github/workflows/ci.yml). A documented Checkov exception is a
known boundary, not proof that the underlying control exists.

## Runtime Delivery

| Invariant | Primary evidence |
| --- | --- |
| Application images and environment interfaces follow the app-owned contract | [App deployment contract](https://github.com/ivanprytula/api-observatory/blob/main/docs/07-deployment/app-repo-contract.md) |
| Cloud credentials are short-lived through GitHub OIDC; EC2 receives runtime values through its SSM role, not GitHub | [CI/CD guide](../ci-cd/ci-cd.md) |
| Rollout, health verification, and rollback are explicit steps | [Deployment guide](../deployment/deployment-guide.md) |
| Kubernetes examples run non-root, drop capabilities, and avoid committed real secrets | [`kubernetes/`](../../kubernetes/) |

Kubernetes and Azure assets are secondary/reference evidence. They do not expand the current AWS
Stage 0 deployment claim without a measured trigger and fresh validation.

## Operations and Recovery

| Invariant | Primary evidence |
| --- | --- |
| Prometheus, Alertmanager, Loki/Promtail, and Grafana configuration has one infra owner | [Observability guide](../operations/observability.md) |
| Alert thresholds and dashboards point to signals the application actually exports | [`monitoring/`](../../monitoring/) plus app signal documentation |
| SLO, breaker, DLQ, restore, and fault scenarios have bounded response paths | [Recovery guide](../operations/recovery-guide.md) |
| Backup and fault scripts count only after current-target execution and retained recovery evidence | [Recovery guide](../operations/recovery-guide.md) |

## Change Test

Keep an invariant only when it protects a current contract, security boundary, or recovery path.
Add tooling only for an uncovered control or measured stage trigger. Git history carries resolved
issues and status history; this file carries only the baseline that must remain true.
