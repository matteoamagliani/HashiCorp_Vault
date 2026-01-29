# 01-dev-lab.ps1
# Start dev mode and run the basic credential-service lab.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\ps1\01-dev-lab.ps1

. "$PSScriptRoot\00-env.ps1"

docker compose -f docker\docker-compose.dev.yml up -d

Write-Host "Logging in to dev mode with token: dev-only-token"
vault login dev-only-token

Write-Host "Running credential service setup..."
& "$PSScriptRoot\03-credential-service-setup.ps1"

Write-Host "Running tests..."
& "$PSScriptRoot\04-tests.ps1"

Write-Host "Done. See docs\dev_cli.md for the full manual flow (dev mode)."
