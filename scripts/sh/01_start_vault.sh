#!/usr/bin/env bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_vault.sh"

echo "VAULT_ADDR=${VAULT_ADDR}" >&2
echo "VAULT_TOKEN=${VAULT_TOKEN:-}" >&2

# Wait a moment for Vault to accept requests
for _ in {1..20}; do
	if vault status >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

vault status
