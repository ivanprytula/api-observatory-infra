#!/usr/bin/env bash
# Shared logging helpers for all scripts.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

log()   { echo "[$(date '+%H:%M:%S')] $*"; }
warn()  { echo "[$(date '+%H:%M:%S')] WARN: $*" >&2; }
error() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }
die()   { error "$@"; exit 1; }
