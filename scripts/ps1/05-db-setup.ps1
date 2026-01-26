# 05-db-setup.ps1
# Optional: configure Postgres dynamic creds and test lease revoke.
# Start with:
#   docker compose -f docker\docker-compose.server-db.yml up -d
# then init/unseal/login, then run this script.

. "$PSScriptRoot\00-env.ps1"

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
