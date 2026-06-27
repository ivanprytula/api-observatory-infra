# ─── API Observatory Infra ────────────────────────────────────────────────────
#
# Multi-cloud infrastructure management for api-observatory.
# App repo: github.com/ivanprytula/api-observatory
#
# Azure (current):
#   TF_ENV=azure-sandbox just tf init    # floci-az emulator (default)
#   TF_ENV=azure-dev just tf plan        # Azure cloud
#   just ansible-run provision-azure-vm  # provision Azure VM
#
# AWS:
#   TF_ENV=aws-sandbox just tf init      # LocalStack emulator
#   TF_ENV=aws-dev just tf plan          # AWS cloud
#   just ansible-run provision-aws-ec2   # provision EC2 instance
#
# Cloud-neutral:
#   just helm-lint                       # lint all Helm charts
#   just k3d-up                          # local K8s cluster

# ─── TERRAFORM ────────────────────────────────────────────────────────────────
#
# Environments:
#   azure-sandbox  — floci-az emulator (default)
#   azure-dev      — Azure cloud (B1s free tier)
#   aws-sandbox    — LocalStack emulator
#   aws-dev        — AWS cloud (t2.micro free tier)
#
# Usage:
#   just tf init                          # defaults to azure-sandbox
#   just tf plan
#   just tf apply
#   TF_ENV=aws-dev just tf plan           # target AWS dev
#   just tf fresh                         # init → plan → apply

tf cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    ENV="${TF_ENV:-azure-sandbox}"
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
            BACKEND_CFG=$(ls backend.*.hcl 2>/dev/null | head -1)
            if [ -n "${BACKEND_CFG:-}" ]; then
                terraform init -reconfigure -upgrade -backend-config="$BACKEND_CFG"
            else
                terraform init -reconfigure -upgrade
            fi
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
            terraform show
            ;;
        destroy)
            terraform destroy \
                -auto-approve \
                -var-file=terraform.tfvars
            ;;
        fresh)
            just tf init
            just tf plan
            just tf apply
            ;;
        *)
            echo "Usage: just tf <init|validate|plan|apply|show|destroy|fresh>"; exit 1
            ;;
    esac

tf-destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    ENV="${TF_ENV:-azure-sandbox}"
    EXPECTED="yes-i-really-want-to-destroy-${ENV}"
    read -r -p "DANGER: Type '${EXPECTED}' to destroy ${ENV} infra: " CONFIRM
    if [ "$CONFIRM" != "$EXPECTED" ]; then
        echo "Aborted."
        exit 1
    fi
    just tf destroy

# ─── ANSIBLE ──────────────────────────────────────────────────────────────────
#
# Usage:
#   just ansible-run sandbox-host         # run a playbook
#   just ansible-run provision-azure-vm   # provision Azure VM
#   just ansible-run provision-aws-ec2    # provision AWS EC2
#   just ansible-lint                     # lint all playbooks

ansible-run playbook:
    #!/usr/bin/env bash
    set -euo pipefail
    PLAYBOOK="ansible/playbooks/{{playbook}}.yml"
    if [ ! -f "$PLAYBOOK" ]; then
        echo "FAIL: Playbook not found: ${PLAYBOOK}" >&2
        echo "  Available:" >&2
        ls ansible/playbooks/*.yml | xargs -I{} basename {} .yml | sed 's/^/    /' >&2
        exit 1
    fi
    ansible-playbook "$PLAYBOOK"

ansible-lint:
    ansible-lint ansible/playbooks/*.yml

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

aws-provision:
    bash scripts/aws-provision.sh

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
