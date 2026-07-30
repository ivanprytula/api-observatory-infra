#!/usr/bin/env bash
set -o errexit -o pipefail -o nounset -o errtrace

readonly COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
readonly DEPLOYMENT_ENV_FILE="${DEPLOYMENT_ENV_FILE:-.runtime/deployment.env}"
readonly PREVIOUS_ENV_FILE="${DEPLOYMENT_ENV_FILE}.previous"
previous_ingestor=""
previous_dashboard=""
rollback_needed=true
profile_args=()

configure_profiles() {
  local profile
  [[ -n "${ENABLED_PROFILES:-}" ]] || return
  IFS=',' read -r -a profiles <<< "${ENABLED_PROFILES}"
  for profile in "${profiles[@]}"; do
    case "${profile}" in inference|cache|broker|monitoring) profile_args+=(--profile "${profile}") ;; *) error "Unsupported profile: ${profile}"; return 1 ;; esac
  done
}
profile_enabled() {
  case ",${ENABLED_PROFILES:-}," in
    *,"$1",*) return 0 ;;
    *) return 1 ;;
  esac
}
compose() { docker compose --env-file "${DEPLOYMENT_ENV_FILE}" "${profile_args[@]}" -f "${COMPOSE_FILE}" "$@"; }
error() { echo "[ERROR] $*" >&2; }
current_image() { local id; id="$(compose ps -q "$1")"; [[ -z "$id" ]] || docker inspect --format '{{.Config.Image}}' "$id"; }

rollback() {
  [[ "$rollback_needed" == true ]] || return
  if [[ -z "$previous_ingestor" || -z "$previous_dashboard" ]]; then
    compose down --remove-orphans || true
    rm -f "${DEPLOYMENT_ENV_FILE}"
    return
  fi
  mv "${PREVIOUS_ENV_FILE}" "${DEPLOYMENT_ENV_FILE}"
  compose up -d
}

wait_for() {
  local url="$1" attempt=1
  while ((attempt <= 30)); do curl --fail --silent "$url" >/dev/null && return; sleep 2; ((attempt += 1)); done
  error "Readiness check failed: ${url}"; return 1
}

main() {
  [[ -r "$DEPLOYMENT_ENV_FILE" ]] || { error "Missing desired-state deployment env."; exit 1; }
  configure_profiles
  previous_ingestor="$(current_image ingestor)"
  previous_dashboard="$(current_image dashboard)"
  compose pull
  compose up -d --wait ingestor-db
  compose run --rm --no-deps ingestor alembic upgrade head
  if profile_enabled inference; then
    compose up -d --wait inference-db
    compose run --rm --no-deps inference alembic upgrade head
  fi
  compose up -d
  wait_for http://127.0.0.1:8000/readyz
  wait_for http://127.0.0.1:8501/_stcore/health
  if profile_enabled inference; then
    wait_for http://127.0.0.1:8001/readyz
  fi
  compose exec -T dashboard python -c "import urllib.request; urllib.request.urlopen('http://ingestor:8000/readyz', timeout=5)"
  compose exec -T ingestor python -c '
import urllib.request
from services.ingestor.auth import create_jwt_token
token = create_jwt_token("stage0-smoke", {"roles": ["admin"]})
request = urllib.request.Request("http://127.0.0.1:8000/api/v1/scorecards", headers={"Authorization": f"Bearer {token}"})
urllib.request.urlopen(request, timeout=5).close()
'
  rollback_needed=false
  rm -f "$PREVIOUS_ENV_FILE"
}

trap 'rollback' ERR
main "$@"
