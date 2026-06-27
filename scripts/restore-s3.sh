#!/usr/bin/env bash
set -euo pipefail

# AWS S3 restore variant — downloads backup from S3, then restores via restore.sh.
#
# Usage:
#   ./restore-s3.sh postgres postgres/pg_api_observatory_20260101_120000.sql.gz
#   ./restore-s3.sh mongodb mongodb/mongo_data_zoo_20260101_120000.archive.gz
#   ./restore-s3.sh list                # list available backups in S3
#
# Required env vars:
#   AWS_S3_BUCKET          — source bucket name
#   AWS_DEFAULT_REGION     — (or AWS_REGION)
# Optional:
#   BACKUP_S3_PREFIX       — key prefix (default: empty)
#   AWS_ENDPOINT_URL       — for LocalStack (http://localhost:4566)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

AWS_S3_BUCKET="${AWS_S3_BUCKET:?AWS_S3_BUCKET is required}"
BACKUP_S3_PREFIX="${BACKUP_S3_PREFIX:-}"
ENDPOINT_FLAG=""
if [[ -n "${AWS_ENDPOINT_URL:-}" ]]; then
    ENDPOINT_FLAG="--endpoint-url ${AWS_ENDPOINT_URL}"
fi

download_from_s3() {
    local s3_key="${1}"
    local tmp_file
    tmp_file="$(mktemp /tmp/restore_s3_XXXXXXXXXX)"
    local src="s3://${AWS_S3_BUCKET}/${BACKUP_S3_PREFIX}${s3_key}"

    log "Downloading ${src} → ${tmp_file}"
    # shellcheck disable=SC2086
    aws s3 cp "${src}" "${tmp_file}" ${ENDPOINT_FLAG}
    log "S3 download complete"
    echo "${tmp_file}"
}

list_s3_backups() {
    log "Listing backups in s3://${AWS_S3_BUCKET}/${BACKUP_S3_PREFIX}"
    # shellcheck disable=SC2086
    aws s3 ls "s3://${AWS_S3_BUCKET}/${BACKUP_S3_PREFIX}" --recursive ${ENDPOINT_FLAG}
}

usage() {
    echo "Usage: $0 <postgres|mongodb> <s3-key>"
    echo "       $0 list"
    echo ""
    echo "Examples:"
    echo "  $0 postgres postgres/pg_api_observatory_20260101_120000.sql.gz"
    echo "  $0 mongodb mongodb/mongo_data_zoo_20260101_120000.archive.gz"
    echo "  $0 list"
    exit 1
}

case "${1:-}" in
    postgres|mongodb)
        [[ -z "${2:-}" ]] && { error "Missing S3 key"; usage; }
        tmp=$(download_from_s3 "${2}")
        bash "${SCRIPT_DIR}/restore.sh" "${1}" "${tmp}"
        rm -f "${tmp}"
        ;;
    list)
        list_s3_backups
        ;;
    *)
        usage
        ;;
esac
