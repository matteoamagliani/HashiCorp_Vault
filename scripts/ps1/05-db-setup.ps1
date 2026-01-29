# 05-db-setup.ps1
# Optional: configure Postgres dynamic creds and test lease revoke.
# Start with:
#   docker compose -f docker\docker-compose.server-db.yml up -d
# then init/unseal/login, then run this script.

. "$PSScriptRoot\00-env.ps1"

function Require-VaultRoot {
  $lookupJson = vault token lookup -format=json 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($lookupJson)) {
    Write-Host "Not logged in to Vault (or VAULT_TOKEN missing)."
    Write-Host "Server+DB mode: run .\\scripts\\ps1\\02-server-init-unseal.ps1 (or login with your root token), then retry."
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
    exit 1
  }
}

Require-VaultRoot

Write-Host "Enabling database secrets engine..."
vault secrets enable database 2>$null

Write-Host "Configuring postgres connection (service name: vault-postgres)..."
vault write database/config/postgres `
  plugin_name=postgresql-database-plugin `
  allowed_roles=readonly `
  connection_url="postgresql://{{username}}:{{password}}@vault-postgres:5432/demo?sslmode=disable" `
  username="vaultadmin" `
  password="vaultadminpw" | Out-Null

Write-Host "Creating role readonly (TTL 1m)..."
vault write database/roles/readonly `
  db_name=postgres `
  creation_statements="CREATE ROLE ""{{name}}"" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO ""{{name}}"";" `
  default_ttl="1m" `
  max_ttl="10m" | Out-Null

Write-Host "Requesting dynamic credentials..."
$creds = vault read -format=json database/creds/readonly | ConvertFrom-Json
$lease = $creds.lease_id
$dbUser = $creds.data.username
$dbPass = $creds.data.password

Write-Host "Issued user: $dbUser"
Write-Host "Lease id: $lease"

Write-Host "Revoking lease (immediate deprovision)..."
vault lease revoke $lease

Write-Host "DB creds demo complete."
