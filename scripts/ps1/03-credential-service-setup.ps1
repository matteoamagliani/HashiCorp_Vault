# 03-credential-service-setup.ps1
# Operator setup for "credentials storage service" (audit + KV v2 + policy + identity)
# Works in dev mode and server mode once authenticated as an operator/root.

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
		Write-Host "This script requires an operator/root token (policy: root)."
		Write-Host ("Current token policies: {0}" -f ($policies -join ", "))
		Write-Host "If you are logged in as a restricted user (e.g., payments-app), login as root and retry."
		exit 1
	}
}

Require-VaultRoot

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
