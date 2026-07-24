# Deployment Guide (Azure Reference)

> AWS is the primary portfolio deployment target: Stage 0 uses EC2 + Docker
> Compose, RDS PostgreSQL, ECR, and GitHub Actions OIDC. This Azure document is
> retained as secondary/reference material; do not use it as the default path for
> new deployment work. See the app repository's AWS deployment guide and the
> `aws-dev` Terraform environment for the primary path.

## Overview

The API Observatory deploys to a single Azure B1s VM running Docker Compose. CI builds and pushes images to Azure Container Registry (ACR). CD deploys via SSH to the VM.

## Architecture

```text
GitHub Actions CI                    Azure Free Tier
┌──────────────┐                    ┌──────────────────────┐
│ lint, test,  │                    │  B1s VM (Docker)     │
│ build, scan  │──push images──►   │  ├─ ingestor:8000    │
│              │                    │  ├─ dashboard:8501   │
│  ACR push    │                    │  ├─ postgres:5432    │
└──────┬───────┘                    │  ├─ redis:6379       │
       │                            │  └─ nginx:80/443     │
       │  CD (SSH deploy)           └──────────────────────┘
       └────────────────────────────►  docker compose up -d
```

## Prerequisites

- Azure CLI installed and logged in: `az login`
- SSH key pair (generated during VM provisioning)
- GitHub repo secrets configured (see `docs/ci-cd/github-secrets-setup.md`)

## First-Time Setup

### 1. Provision Infrastructure

```bash
az login

cp terraform/environments/azure-dev/terraform.tfvars.example terraform/environments/azure-dev/terraform.tfvars
# fill in: subscription_id, admin_cidr (your public IP, curl ifconfig.me),
#          ssh_public_key, pg_admin_password (strong, unique)

TF_ENV=azure-dev just tf init    # no backend.azure.hcl yet -> local state, fine for first bootstrap
TF_ENV=azure-dev just tf plan
TF_ENV=azure-dev just tf apply
```

This creates:

- Resource group, VNet, subnet, NSG (SSH, HTTP, HTTPS inbound)
- B1s VM with public IP
- PostgreSQL Flexible Server (B1ms, VNet-integrated, no public endpoint)

Then configure the VM (Docker install, hardening):

```bash
# terraform output the VM's public IP, then update ansible/inventory/hosts.yml:
#   azure_dev.ansible_host -> the real VM IP (currently a placeholder)
just ansible-run provision-azure-vm
```

> `infra/scripts/azure-provision.sh` (imperative `az` CLI provisioning) predates this Terraform
> setup and creates the same resource group/VM by a different path. Don't run both against the
> same subscription — they'll collide or leave resources outside Terraform's state.

### 2. Configure GitHub Secrets

Follow the checklist in `docs/ci-cd/github-secrets-setup.md`:

- `ACR_LOGIN_SERVER`, `ACR_USERNAME`, `ACR_PASSWORD`
- `AZURE_CREDENTIALS`, `AZURE_VM_SSH_KEY`, `AZURE_VM_HOST_KEY`
- Create `dev` environment with approval gate

### 3. Deploy Docker Compose to VM

```bash
VM_IP=$(az vm show --resource-group api-observatory-rg --name api-observatory-vm --show-details --query publicIps -o tsv)
scp docker-compose.yml .env azureuser@${VM_IP}:~/app/
ssh azureuser@${VM_IP} "cd ~/app && docker compose up -d"
```

### 4. Verify

```bash
curl http://${VM_IP}:8000/health
curl http://${VM_IP}:8501/_stcore/health
```

## CI/CD Flow

1. Push to `develop` → CI runs (lint, test, Docker build + push to ACR, Trivy scan)
2. CI passes → CD triggers with manual approval gate
3. CD: SSH into VM → `docker login` to ACR → `docker pull` → `docker compose up -d` → health check → smoke test

## Manual Deploy

```bash
VM_IP=$(az vm show --resource-group api-observatory-rg --name api-observatory-vm --show-details --query publicIps -o tsv)
TREE_SHA=$(git rev-parse HEAD^{tree} | cut -c1-7)
ACR="<your-acr-name>.azurecr.io"

ssh azureuser@${VM_IP} bash -s <<EOF
set -euo pipefail
cd ~/app
docker pull ${ACR}/api-observatory/ingestor:tree-${TREE_SHA}
docker pull ${ACR}/api-observatory/dashboard:tree-${TREE_SHA}
docker tag ${ACR}/api-observatory/ingestor:tree-${TREE_SHA} api-observatory/ingestor:latest
docker tag ${ACR}/api-observatory/dashboard:tree-${TREE_SHA} api-observatory/dashboard:latest
docker compose down --timeout 30
docker compose up -d
docker image prune -f --filter "until=48h"
EOF
```

## Local Emulator Development

Floci-az emulator dev tooling (`sandbox-up`/`sandbox-dev`/`sandbox-validate`/`cloud-preflight`)
lives in the `api-observatory` app repo, not here — this repo only provisions real cloud
infrastructure. See that repo's `docs/07-deployment/deployment-guide.md`.

## Terraform

```bash
TF_ENV=azure-dev just tf init        # real Azure — see "Provision Infrastructure" above
TF_ENV=azure-dev just tf plan
TF_ENV=azure-dev just tf apply
```

## Cost

All resources within Azure Free Tier (12-month window):

| Resource | Free Limit | Usage |
|----------|-----------|-------|
| B1s VM | 750 hrs/month | ~730 hrs (always-on) |
| ACR Standard | 1 unit/day | Image pushes on deploy |
| Blob Storage (Hot LRS) | 5 GB | Backups, archives |
| Data Transfer Out | 15 GB/month | API + dashboard traffic |

Estimated monthly cost: **$0** (within free tier limits).

## Troubleshooting

### VM not responding

```bash
az vm start --resource-group api-observatory-rg --name api-observatory-vm
```

### Docker Compose issues on VM

```bash
ssh azureuser@${VM_IP} "cd ~/app && docker compose logs --tail=50"
```

### ACR login expired on VM

```bash
ssh azureuser@${VM_IP} "az acr login --name <your-acr-name>"
```
