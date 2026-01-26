# 02-server-init-unseal.ps1
# Initialize/unseal server mode (first time) and login as root.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\ps1\02-server-init-unseal.ps1

. "$PSScriptRoot\00-env.ps1"

docker compose -f docker\docker-compose.server.yml up -d

Write-Host "Checking vault status..."
vault status

Write-Host "Initializing Vault (1 share, threshold 1) if needed..."
# Try init; if already initialized, Vault returns an error. We'll handle it.
try {
    $init = vault operator init -key-shares=1 -key-threshold=1 -format=json | ConvertFrom-Json
    $unsealKey = $init.unseal_keys_b64[0]
    $rootToken = $init.root_token

    $init | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 .\server-init.json
    Write-Host "Saved init material to .\server-init.json (demo only)."

    Write-Host "Unsealing..."
    vault operator unseal $unsealKey

    Write-Host "Logging in as root..."
    vault login $rootToken
}
catch {
    Write-Host "Init likely failed because Vault is already initialized."
    Write-Host "If sealed, unseal with your previously saved unseal key, then login with your root token."
}

vault status
