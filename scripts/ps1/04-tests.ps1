# 04-tests.ps1
# Runs the test suite T1..T4 + audit check. (T5 DB creds is in 05-db-setup.ps1)
# Assumes authenticated operator/root.

. "$PSScriptRoot\00-env.ps1"

Write-Host "T1: Read seeded secret"
vault kv get -mount=app-secrets payments/stripe

Write-Host "T2: Update secret (creates new version)"
vault kv put -mount=app-secrets payments/stripe api_key="sk_test_NEW_VALUE" | Out-Null
vault kv metadata get -mount=app-secrets payments/stripe
Write-Host "T2: Read version 1 (rollback demonstration)"
vault kv get -mount=app-secrets -version=1 payments/stripe

Write-Host "T3: Policy enforcement test (login as payments-app)"
vault login -method=userpass username=payments-app password="P@ss-demo-Only" -no-print | Out-Null
Write-Host "T3: Allowed read (should succeed)"
vault kv get -mount=app-secrets payments/stripe
Write-Host "T3: Forbidden read (should fail)"
vault kv get -mount=app-secrets payments/other-service

Write-Host "Re-login as dev root (dev-only-token) or server root as needed before T4."
Write-Host "If you are in dev mode, run: vault login dev-only-token"
Write-Host "If you are in server mode, login with your root token."

Write-Host "T4: Short-lived token lifecycle"
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
