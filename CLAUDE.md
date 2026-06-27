# API Observatory Infra — Project Instructions

## Stack

- **IaC**: Terraform (Azure + AWS providers), Ansible
- **Orchestration**: Kubernetes (k3d local, AKS/EKS target), Helm charts
- **Monitoring**: Prometheus, Alertmanager, Promtail (cloud-neutral)
- **Target Clouds**: Azure (B1s free tier), AWS (t2.micro free tier)
- **Local Emulators**: floci-az (Azure), LocalStack (AWS)
- **App Repo**: github.com/ivanprytula/api-observatory (source of container images)

## Multi-Cloud Layout

Each cloud gets its own directory under `terraform/environments/`:

- `azure-sandbox` / `azure-dev` — Azure environments
- `aws-sandbox` / `aws-dev` — AWS environments

Scripts have cloud-specific variants: `backup.sh` (local/blob), `backup-s3.sh` (S3).
Ansible inventory uses group-per-cloud: `azure_dev`, `aws_dev`.
Kubernetes, monitoring, and Helm are cloud-neutral.

## Contract with App Repo

- **Image tags**: CI in the app repo pushes images tagged `tree-<SHA>` (ACR or ECR)
- **Health endpoints**: Ingestor `/health` on port `8000`, Dashboard on port `8501`
- **Env vars**: App documents required config in `.env.example`

## Shell Scripting

- Always use `set -euo pipefail` and `trap` for cleanup.
- Echo key variables (location, IP, SKU) before use to make failures visible.
- Never suppress errors in provisioning scripts.

## Terraform Conventions

- One environment per directory under `terraform/environments/`.
- Use `terraform.tfvars.example` for documenting required variables.
- Backend config lives in `backend.azure.hcl.example` (Azure) or `backend.s3.hcl.example` (AWS).
- Pin provider versions explicitly.
- Keep AWS and Azure environments structurally parallel (same variable names where possible).

## Ansible Conventions

- Playbooks in `ansible/playbooks/`, inventory in `ansible/inventory/`.
- Use `ansible.cfg` at repo root for defaults.
- Tag tasks for selective runs.

## Kubernetes Conventions

- Raw manifests in `kubernetes/manifests/`, Helm charts in `kubernetes/charts/`.
- Kustomize overlays in `kubernetes/overlays/` for environment-specific patches.
- Network policies are mandatory for all services.

## Git & Commits

- Use conventional commit prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
- Keep commits atomic and grouped by logical change.

## Safety

- Never delete infrastructure resources without explicit confirmation.
- Always run `terraform plan` before `terraform apply`.
- Prefer `terraform plan -out=tfplan` then `terraform apply tfplan` workflow.
