# 03-credential-service-setup.ps1
# Operator setup for "credentials storage service" (audit + KV v2 + policy + identity)
# Works in dev mode and server mode once authenticated as an operator/root.

. "$PSScriptRoot\00-env.ps1"

Write-Host "Enabling audit logging..."
vault audit enable file file_path=/vault/logs/vault-audit.log 2>$null
vault audit list

Write-Host "Enabling KV v2 at app-secrets/ ..."
vault secrets enable -path=app-secrets -version=2 kv 2>$null
vault secrets list | Select-String "app-secrets"

Write-Host "Writing app-cred-policy..."
vault policy write app-cred-policy .\docker\vault\policies\app-cred-policy.hcl
vault policy read app-cred-policy | Out-Host

Write-Host "Enabling userpass and creating restricted user payments-app..."
vault auth enable userpass 2>$null
vault write auth/userpass/users/payments-app password="P@ss-demo-Only" policies="app-cred-policy" | Out-Null

Write-Host "Seeding a demo secret (payments/stripe)..."
vault kv put -mount=app-secrets payments/stripe api_key="sk_test_REPLACE_ME" account="demo-account" | Out-Null

Write-Host "Setup complete."
