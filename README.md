# API Observatory — Infrastructure

Multi-cloud Infrastructure-as-Code for the [API Observatory](https://github.com/ivanprytula/api-observatory) platform.

AWS is the primary portfolio deployment direction; Azure remains secondary/reference
infrastructure. The [evolution plan](docs/architecture/evolution-plan.md) owns platform stages and
adoption triggers, while the [baseline](docs/architecture/baseline-checklist.md) owns durable
security/SRE controls.

For the whole product-to-platform story, start with the app-owned
[Application Lifecycle and SDLC](https://github.com/ivanprytula/api-observatory/blob/main/docs/01-intro/application-lifecycle.md).
It follows one vertical slice from idea and planning through development, delivery, operations,
maintenance, and transformation, with direct links back to this repository at each platform stage.

## Repository Structure

```text
terraform/
  environments/
    azure-dev/           Azure cloud (B1s free tier)
    aws-dev/             AWS cloud (t2.micro free tier)
ansible/                 Playbooks, inventory (multi-cloud), roles
kubernetes/              K8s manifests, Helm charts, overlays (cloud-neutral)
monitoring/              Prometheus, Alertmanager, Grafana (cloud-neutral)
security/                Seccomp profiles
scripts/                 Provisioning, backup/restore (per-cloud variants)
docs/                    CI, deployment, observability, recovery, evolution, baseline
```

Sandbox environments (floci-az, floci-aws) live in the **app repo** — they're dev tooling.

## Working with the Repository

The [`Justfile`](Justfile) owns Terraform, Ansible, Kubernetes, Helm, backup/restore, and validation
command syntax. Start with static validation and a reviewed Terraform plan. Any apply, deployment,
restore, chaos action, or teardown requires explicit target review and approval.

## Contract with App Repo

| Contract | AWS primary Stage 0 | Azure secondary/reference |
| --- | --- | --- |
| Image registry | ECR | ACR |
| Deployable services | ingestor `:8000`, inference `:8001`, dashboard `:8501` | Same application contract |
| Image tag format | `tree-<SHA>` | `tree-<SHA>` |
| Compute | EC2 + Docker Compose | VM + Docker Compose |
| Config schema | App repo environment contract | Same |

## Platform Direction

Stage 0 co-locates the three application images on EC2 + Docker Compose with RDS and ECR. This is a
planned/configured path, not a completed deployment. ECS/Fargate requires independent workload
pressure; Kubernetes remains a later evidence-triggered stage. Azure assets are retained only for
comparison and foundational learning.

## Prerequisites

Pre-commit hooks run most checks in isolated environments. The following system
packages must be installed separately (not available as pre-commit hooks):

- **terraform** — `terraform fmt`, `terraform validate`
- **tflint** — `terraform_tflint` hook, install via [tflint.io/docs/install](https://tflint.io/docs/install)

Additional tools used outside pre-commit:

- **jq**, **curl**, **unzip**, **gnupg**, **azure-cli**, **aws-cli** — see deployment guide
- **docker**, **kubectl**, **helm**, **k3d**, **just** — local dev tooling

Continue with the [deployment guide](docs/deployment/deployment-guide.md),
[platform observability](docs/operations/observability.md), or
[recovery guide](docs/operations/recovery-guide.md).
