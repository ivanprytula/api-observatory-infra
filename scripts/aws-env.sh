#!/usr/bin/env bash
set -euo pipefail

# Source AWS environment variables from Terraform outputs.
# Usage: source scripts/aws-env.sh
#        eval "$(scripts/aws-env.sh)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/aws-dev"

if [[ ! -d "${TF_DIR}/.terraform" ]]; then
    echo "ERROR: Terraform not initialized. Run: TF_ENV=aws-dev just tf init" >&2
    exit 1
fi

cd "${TF_DIR}"

VM_IP=$(terraform output -raw instance_public_ip 2>/dev/null) || VM_IP=""
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null) || RDS_ENDPOINT=""
RDS_DB=$(terraform output -raw rds_database_name 2>/dev/null) || RDS_DB=""

echo "export VM_IP='${VM_IP}'"
echo "export RDS_ENDPOINT='${RDS_ENDPOINT}'"
echo "export RDS_DB='${RDS_DB}'"
echo "export CLOUD_PROVIDER='aws'"
