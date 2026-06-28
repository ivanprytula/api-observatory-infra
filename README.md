# API Observatory — Infrastructure

Multi-cloud Infrastructure-as-Code for the [API Observatory](https://github.com/ivanprytula/api-observatory) platform.

Supports **Azure** and **AWS** side-by-side via directory-per-cloud layout.
See [docs/cloud-comparison.md](docs/cloud-comparison.md) for architectural decision log.

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
docs/                    CI/CD, deployment, operations, cloud comparison
```

Sandbox environments (floci-az, floci-aws) live in the **app repo** — they're dev tooling.

## Quick Start

```bash
# ─── Azure ─────────────────────────────────────
TF_ENV=azure-dev just tf plan            # Azure cloud
just ansible-run provision-azure-vm

# ─── AWS ───────────────────────────────────────
TF_ENV=aws-dev just tf plan              # AWS cloud
just ansible-run provision-aws-ec2

# ─── Cloud-neutral ─────────────────────────────
just k3d-up                              # local K8s cluster
just k8s-apply-local                     # deploy to k3d
just helm-lint                           # lint all charts
```

## Contract with App Repo

| Contract         | Azure                   | AWS          |
| ---------------- | ----------------------- | ------------ |
| Image registry   | ACR                     | ECR          |
| Image tag format | `tree-<SHA>`            | `tree-<SHA>` |
| Ingestor health  | `GET /health` `:8000`   | Same         |
| Dashboard health | Port `8501`             | Same         |
| Config schema    | App repo `.env.example` | Same         |

## Target Clouds

| Cloud | Free Tier                       | Compute | Database                   | Local Emulator |
| ----- | ------------------------------- | ------- | -------------------------- | -------------- |
| Azure | B1s 750 hrs/mo (ongoing)        | VM      | PostgreSQL Flexible Server | floci-az       |
| AWS   | t2.micro 750 hrs/mo (12 months) | EC2     | RDS PostgreSQL             | floci-aws      |

Production path: Kubernetes (k3d local → AKS/EKS).

## Prerequisites

Pre-commit hooks run most checks in isolated environments. The following system
packages must be installed separately (not available as pre-commit hooks):

- **terraform** — `terraform fmt`, `terraform validate`
- **tflint** — `terraform_tflint` hook, install via [tflint.io/docs/install](https://tflint.io/docs/install)

Additional tools used outside pre-commit (scripts, manual runs):

- **jq**, **curl**, **unzip**, **gnupg**, **azure-cli**, **aws-cli** — see deployment guide
- **docker**, **kubectl**, **helm**, **k3d**, **just** — local dev tooling

See [docs/deployment/deployment-guide.md](docs/deployment/deployment-guide.md) for full setup.
