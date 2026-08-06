#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

show_tool() {
    local command_name="$1"
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf '⚠ %-18s not found (CI/pre-commit may provide it)\n' "${command_name}"
        return 0
    fi

    local version_output
    if version_output="$("${command_name}" --version 2>&1)"; then
        printf '✓ %-18s %s\n' "${command_name}" "${version_output%%$'\n'*}"
    else
        printf '✓ %-18s version probe unavailable\n' "${command_name}"
    fi
}

echo "Infrastructure repository doctor"
echo "PATH and version diagnostics only; no files, credentials, state, hosts, or network are accessed."
echo

for command_name in \
    just \
    git \
    terraform \
    ansible-playbook \
    ansible-lint \
    uv \
    yamllint \
    tflint \
    shellcheck \
    checkov; do
    show_tool "${command_name}"
done
