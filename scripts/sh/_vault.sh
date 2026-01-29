#!/usr/bin/env bash

set -euo pipefail

# Minimal helper:
# - If 'vault' exists locally -> use it.
# - Else -> use the 'vault' CLI inside the running Docker container (dev mode).

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

_is_wsl() {
  # WSL1/WSL2 typically contain 'Microsoft' in the kernel version string.
  grep -qi microsoft /proc/version 2>/dev/null
}

_repo_root() {
  (cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
}

_need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' not found." >&2
    exit 1
  }
}

_start_dev_stack_if_needed() {
  _need docker

  if docker ps --format '{{.Names}}' | grep -Fxq vault-dev; then
    return 0
  fi

  echo "Starting Vault dev stack (docker compose)..." >&2
  (cd -- "$(_repo_root)" && docker compose -f docker/docker-compose.dev.yml up -d)
}

_configure_vault() {
  # Prefer Docker in WSL, because 'vault' often resolves to a Windows vault.exe
  # via interop and can crash (segfault) when invoked from Linux.
  # If you installed a native Linux Vault and want to use it, set: VAULT_USE_LOCAL=1
  local vault_path
  vault_path="$(command -v vault 2>/dev/null || true)"

  if [[ "${VAULT_USE_LOCAL:-}" == "1" ]] && [[ -n "${vault_path}" ]] && [[ "${vault_path}" != *.exe ]]; then
    VAULT_BIN=(vault)
    return 0
  fi

  if [[ -n "${vault_path}" ]] && [[ "${vault_path}" != *.exe ]] && ! _is_wsl; then
    VAULT_BIN=(vault)
    return 0
  fi

  _start_dev_stack_if_needed
  export VAULT_TOKEN="${VAULT_TOKEN:-dev-only-token}"
  VAULT_BIN=(docker exec -i -e VAULT_ADDR -e VAULT_TOKEN vault-dev vault)
}

vault() {
  # shellcheck disable=SC2154
  "${VAULT_BIN[@]}" "$@"
}

_configure_vault
