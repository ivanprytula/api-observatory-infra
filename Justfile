# ─── API Observatory Infra ────────────────────────────────────────────────────
#
# Multi-cloud infrastructure management for api-observatory.
# App repo: github.com/ivanprytula/api-observatory
#
# Azure reference:
#   TF_ENV=azure-sandbox just tf init    # floci-az emulator
#   TF_ENV=azure-dev just tf plan        # Azure cloud
#   just ansible-run provision-azure-vm  # provision Azure VM
#
# AWS:
#   TF_ENV=aws-sandbox just tf init      # LocalStack emulator
#   TF_ENV=aws-dev just tf plan          # AWS cloud
#
# Cloud-neutral:
#   just helm-lint                       # lint all Helm charts
#   just k3d-up                          # local K8s cluster

# ─── TERRAFORM ────────────────────────────────────────────────────────────────
#
# Environments:
#   azure-sandbox  — floci-az emulator
#   azure-dev      — Azure reference environment
#   aws-sandbox    — LocalStack emulator
#   aws-dev        — AWS Stage 0 environment
#
# Usage:
#   TF_ENV=aws-dev just tf init
#   TF_ENV=aws-dev just tf plan
#   TF_ENV=aws-dev just tf show
#   TF_ENV=aws-dev just tf apply

tf cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    ENV="${TF_ENV:?Set TF_ENV explicitly, for example TF_ENV=aws-dev}"
    CMD="{{cmd}}"
    DIR="terraform/environments/${ENV}"
    if [ ! -d "$DIR" ]; then
        echo "FAIL: Terraform environment directory not found: ${DIR}" >&2
        echo "  Available: $(ls terraform/environments/)" >&2
        exit 1
    fi
    cd "$DIR"

    case "$CMD" in
        init)
            shopt -s nullglob
            BACKEND_CONFIGS=(backend.*.hcl)
            if [ "${#BACKEND_CONFIGS[@]}" -eq 0 ]; then
                echo "FAIL: Missing backend configuration for ${ENV}." >&2
                echo "  Copy backend.s3.hcl.example to backend.s3.hcl, fill it locally," >&2
                echo "  and create the named versioned S3 state bucket first." >&2
                exit 1
            fi
            if [ "${#BACKEND_CONFIGS[@]}" -gt 1 ]; then
                echo "FAIL: Multiple backend configuration files found for ${ENV}." >&2
                exit 1
            fi
            terraform init -reconfigure -upgrade -backend-config="${BACKEND_CONFIGS[0]}"
            ;;
        validate)
            terraform validate
            ;;
        plan)
            export TF_IN_AUTOMATION=1
            terraform plan \
                -input=false \
                -var-file=terraform.tfvars \
                -out=tfplan
            ;;
        apply)
            terraform apply tfplan
            ;;
        show)
            terraform show tfplan
            ;;
        *)
            echo "Usage: TF_ENV=<environment> just tf <init|validate|plan|show|apply>"; exit 1
            ;;
    esac

tf-destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    ENV="${TF_ENV:?Set TF_ENV explicitly before destroy}"
    DIR="terraform/environments/${ENV}"
    if [ ! -d "$DIR" ]; then
        echo "FAIL: Terraform environment directory not found: ${DIR}" >&2
        echo "  Available: $(ls terraform/environments/)" >&2
        exit 1
    fi
    EXPECTED="yes-i-really-want-to-destroy-${ENV}"
    read -r -p "DANGER: Type '${EXPECTED}' to destroy ${ENV} infra: " CONFIRM
    if [ "${CONFIRM}" != "${EXPECTED}" ]; then
        echo "Aborted."
        exit 1
    fi
    terraform -chdir="${DIR}" destroy \
        -auto-approve \
        -var-file=terraform.tfvars

help-aws-stage0:
    @echo "1. Create and configure the private S3 state backend from README.md."
    @echo "2. TF_ENV=aws-dev just tf init"
    @echo "3. TF_ENV=aws-dev just tf validate"
    @echo "4. TF_ENV=aws-dev just tf plan"
    @echo "5. TF_ENV=aws-dev just tf show"
    @echo "6. Obtain explicit approval before: TF_ENV=aws-dev just tf apply"
    @echo "7. Bootstrap through the explicit SSM Ansible command in docs/deployment/deployment-guide.md."
    @echo "8. Add runtime SecureStrings outside Git and review a real images.lock.json promotion."
    @echo "9. Dispatch deployment only after the aws-dev environment approval."

promote-images metadata-file:
    uv run python scripts/promote_stage0_images.py "{{metadata-file}}"

# ─── ANSIBLE ──────────────────────────────────────────────────────────────────
#
# Usage:
#   just ansible-run sandbox-host         # run a playbook
#   just ansible-run provision-azure-vm   # provision Azure VM
#   just ansible-lint                     # lint all playbooks

ansible-run playbook:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    PLAYBOOK="playbooks/{{playbook}}.yml"
    if [ ! -f "$PLAYBOOK" ]; then
        echo "FAIL: Playbook not found: ${PLAYBOOK}" >&2
        echo "  Available:" >&2
        ls playbooks/*.yml | xargs -I{} basename {} .yml | sed 's/^/    /' >&2
        exit 1
    fi
    ansible-playbook "$PLAYBOOK"

ansible-lint:
    ansible-lint --project-dir ansible

# ─── KUBERNETES / HELM ────────────────────────────────────────────────────────
#
# Usage:
#   just helm-lint                        # lint all charts
#   just k8s-apply-local                  # apply local overlay via kustomize
#   just k3d-up                           # create local k3d cluster

helm-lint:
    #!/usr/bin/env bash
    set -euo pipefail
    for chart in kubernetes/charts/*/; do
        echo "Linting ${chart}..."
        helm lint "$chart"
    done

k8s-apply-local:
    kubectl apply -k kubernetes/overlays/local

k3d-up:
    k3d cluster create --config kubernetes/k3d.yaml

k3d-down:
    k3d cluster delete api-observatory

# ─── SCRIPTS ──────────────────────────────────────────────────────────────────

# Cloud provisioning
azure-provision:
    bash scripts/azure-provision.sh


# Backup (cloud-neutral local + cloud-specific upload)
backup:
    bash scripts/backup.sh

backup-s3:
    bash scripts/backup-s3.sh

# Restore
restore *args:
    bash scripts/restore.sh {{args}}

restore-s3 *args:
    bash scripts/restore-s3.sh {{args}}

chaos:
    bash scripts/chaos.sh
