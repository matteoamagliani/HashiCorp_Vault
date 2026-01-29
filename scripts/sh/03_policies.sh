#!/usr/bin/env bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_vault.sh"

# When using docker exec, pipe the policy file content via stdin
cat docker/vault/policies/developer-vault-policy.hcl | vault policy write developer-vault-policy -
vault policy list
