#!/usr/bin/env bash
set -euo pipefail

# AWS S3 backup variant — uploads PostgreSQL/MongoDB backups to S3.
# Delegates local backup to backup.sh, then syncs to S3.
#
# Required env vars:
#   AWS_S3_BUCKET          — target bucket name
#   AWS_DEFAULT_REGION     — (or AWS_REGION)
# Optional:
#   BACKUP_S3_PREFIX       — key prefix (default: empty)
#   AWS_ENDPOINT_URL       — for LocalStack (http://localhost:4566)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"

AWS_S3_BUCKET="${AWS_S3_BUCKET:?AWS_S3_BUCKET is required}"
BACKUP_S3_PREFIX="${BACKUP_S3_PREFIX:-}"
ENDPOINT_FLAG=""
if [[ -n "${AWS_ENDPOINT_URL:-}" ]]; then
    ENDPOINT_FLAG="--endpoint-url ${AWS_ENDPOINT_URL}"
fi

upload_to_s3() {
    local local_file="${1}"
    local s3_key="${2}"
    local dest="s3://${AWS_S3_BUCKET}/${BACKUP_S3_PREFIX}${s3_key}"

    log "Uploading ${local_file} → ${dest}"
    # shellcheck disable=SC2086
    aws s3 cp "${local_file}" "${dest}" ${ENDPOINT_FLAG}
    log "S3 upload complete: ${dest}"
}

main() {
    log "Running local backup first..."
    BACKUP_STORAGE=local bash "${SCRIPT_DIR}/backup.sh"

    log "Uploading backups to S3..."

    for f in "${BACKUP_DIR}"/postgres/*.gz; do
        [[ -f "$f" ]] || continue
        upload_to_s3 "$f" "postgres/$(basename "$f")"
    done

    for f in "${BACKUP_DIR}"/mongodb/*.gz; do
        [[ -f "$f" ]] || continue
        upload_to_s3 "$f" "mongodb/$(basename "$f")"
    done

    log "S3 backup sync complete."
}

main "$@"
