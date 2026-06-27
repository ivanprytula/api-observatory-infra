#!/usr/bin/env bash
set -euo pipefail

# Provision AWS EC2 instance for api-observatory.
# Equivalent to azure-provision.sh but for AWS Free Tier (t2.micro).
#
# Prerequisites:
#   - AWS CLI configured (aws configure)
#   - SSH key pair created or imported
#
# Usage:
#   ./aws-provision.sh                    # interactive
#   AWS_REGION=eu-central-1 ./aws-provision.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

trap 'error "Script failed at line $LINENO"' ERR

# ─── Configuration ─────────────────────────────────────────────────────────────
PROJECT="${PROJECT:-api-observatory}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t2.micro}"
KEY_NAME="${KEY_NAME:-${PROJECT}-key}"

log "=== AWS Provisioning ==="
log "  Project:       ${PROJECT}"
log "  Region:        ${AWS_REGION}"
log "  Instance type: ${INSTANCE_TYPE}"
log "  Key name:      ${KEY_NAME}"

# ─── Verify prerequisites ─────────────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
    error "AWS CLI not found. Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
fi

CALLER_IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null) || {
    error "AWS credentials not configured. Run: aws configure"
    exit 1
}
ACCOUNT_ID=$(echo "${CALLER_IDENTITY}" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
log "  AWS Account:   ${ACCOUNT_ID}"

# ─── Check free tier eligibility ───────────────────────────────────────────────
log ""
log "Checking EC2 capacity in ${AWS_REGION}..."
AVAILABILITY=$(aws ec2 describe-instance-type-offerings \
    --location-type availability-zone \
    --filters "Name=instance-type,Values=${INSTANCE_TYPE}" \
    --region "${AWS_REGION}" \
    --query 'InstanceTypeOfferings[].Location' \
    --output text 2>/dev/null) || true

if [[ -z "${AVAILABILITY}" ]]; then
    error "${INSTANCE_TYPE} not available in ${AWS_REGION}"
    exit 1
fi
log "  Available in: ${AVAILABILITY}"

# ─── Find latest Ubuntu 24.04 AMI ─────────────────────────────────────────────
log ""
log "Finding latest Ubuntu 24.04 AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters \
        "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
        "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --region "${AWS_REGION}" \
    --output text)

if [[ -z "${AMI_ID}" || "${AMI_ID}" == "None" ]]; then
    error "Could not find Ubuntu 24.04 AMI in ${AWS_REGION}"
    exit 1
fi
log "  AMI: ${AMI_ID}"

# ─── Check/create key pair ─────────────────────────────────────────────────────
log ""
if aws ec2 describe-key-pairs --key-names "${KEY_NAME}" --region "${AWS_REGION}" &>/dev/null; then
    log "  Key pair '${KEY_NAME}' already exists"
else
    log "  Creating key pair '${KEY_NAME}'..."
    aws ec2 create-key-pair \
        --key-name "${KEY_NAME}" \
        --key-type ed25519 \
        --region "${AWS_REGION}" \
        --query 'KeyMaterial' \
        --output text > "${HOME}/.ssh/${KEY_NAME}.pem"
    chmod 600 "${HOME}/.ssh/${KEY_NAME}.pem"
    log "  Private key saved: ~/.ssh/${KEY_NAME}.pem"
fi

log ""
log "=== Prerequisites verified ==="
log ""
log "Next steps:"
log "  1. cd terraform/environments/aws-dev"
log "  2. cp terraform.tfvars.example terraform.tfvars"
log "  3. Edit terraform.tfvars with your values"
log "  4. just tf init && just tf plan && just tf apply"
