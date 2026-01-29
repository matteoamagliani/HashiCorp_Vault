# 04-tests.ps1
# Runs the test suite T1..T4 + audit check. (T5 DB creds is in 05-db-setup.ps1)
# Assumes authenticated operator/root.

. "$PSScriptRoot\00-env.ps1"

function Require-VaultRoot {
  $lookupJson = vault token lookup -format=json 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($lookupJson)) {
    Write-Host "Not logged in to Vault (or VAULT_TOKEN missing)."
    Write-Host "Dev mode: vault login dev-only-token"
    Write-Host "Server mode: vault login <rootToken>"
    exit 1
  }

  try {
    $lookup = $lookupJson | ConvertFrom-Json
    $policies = @($lookup.data.policies)
  } catch {
    Write-Host "Unable to parse 'vault token lookup' output. Are you logged in?"
    exit 1
  }

  if ($policies -notcontains "root") {
    Write-Host "This script should be started as operator/root (policy: root)."
    Write-Host ("Current token policies: {0}" -f ($policies -join ", "))
    Write-Host "Login as root and retry."
    exit 1
  }
}

Require-VaultRoot

function Get-VaultStorageType {
  $statusJson = vault status -format=json 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($statusJson)) {
    return $null
  }
  try {
    $status = $statusJson | ConvertFrom-Json
    return $status.storage_type
  } catch {
    return $null
  }
}

Write-Host "T1: Read seeded secret"
vault kv get -mount=app-secrets payments/stripe

Write-Host "T2: Update secret (creates new version)"
vault kv put -mount=app-secrets payments/stripe api_key="sk_test_NEW_VALUE" | Out-Null
vault kv metadata get -mount=app-secrets payments/stripe
Write-Host "T2: Read version 1 (rollback demonstration)"
vault kv get -mount=app-secrets -version=1 payments/stripe

Write-Host "T3: Policy enforcement test (login as payments-app)"

# Seed a secret that the restricted user should NOT be able to read.
# This ensures the "Forbidden" test fails with permission denied (not "no value found").
vault kv put -mount=app-secrets payments/other-service token="should_be_denied" | Out-Null

# IMPORTANT: Vault CLI flags must come before the method payload args (username= / password=).
vault login -no-print -method=userpass username=payments-app password="P@ss-demo-Only" | Out-Null
Write-Host "T3: Allowed read (should succeed)"
vault kv get -mount=app-secrets payments/stripe
Write-Host "T3: Forbidden read (should fail)"
vault kv get -mount=app-secrets payments/other-service

Write-Host "T4: Short-lived token lifecycle"

# After T3 we are logged in as the restricted user. Switch back to root before token lifecycle.
$storageType = Get-VaultStorageType
if ($storageType -eq "inmem") {
  Write-Host "Dev mode detected (storage: inmem). Switching back to dev root token..."
  vault login -no-print dev-only-token | Out-Null
  Require-VaultRoot
} else {
  Write-Host "Server mode detected (storage: $storageType)."
  Write-Host "Login as root, then re-run this script to execute T4."
  Write-Host "Example: vault login <rootToken>"
  exit 0
}

$tok = vault token create -ttl=2m -policy=app-cred-policy -format=json | ConvertFrom-Json
$short = $tok.auth.client_token
vault token lookup $short
vault token renew $short
vault token revoke $short

Write-Host "T6: Audit evidence (tail last lines from host file if present)"
if (Test-Path ".\docker\vault\logs\vault-audit.log") {
  Get-Content ".\docker\vault\logs\vault-audit.log" -Tail 20
} else {
  Write-Host "Audit log not found on host yet. It should be at docker\\vault\\logs\\vault-audit.log"
}

Write-Host "Tests complete."
