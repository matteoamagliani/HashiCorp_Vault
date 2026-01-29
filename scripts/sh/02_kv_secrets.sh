#!/usr/bin/env bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_vault.sh"

# Use the same KV mount/path referenced by the existing policy file.
vault secrets enable -path=dev-secrets -version=2 kv
vault kv put dev-secrets/creds password="supersecret"
vault kv get dev-secrets/creds
