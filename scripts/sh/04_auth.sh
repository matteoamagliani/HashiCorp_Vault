#!/usr/bin/env bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_vault.sh"

vault auth enable userpass
vault write auth/userpass/users/demo \
  password="demo123" \
  policies="developer-vault-policy"
