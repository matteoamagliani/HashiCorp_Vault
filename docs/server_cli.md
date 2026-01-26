
# SERVER MODE 

## 1) Start Vault server mode (Docker)

```powershell
docker compose -f docker\docker-compose.server.yml up -d
```
#### Set the Vault address (HTTP for local lab)

```powershell
$env:VAULT_ADDR = "http://127.0.0.1:8200"
```

## 2) Initialize and unseal (first time only)

### 2.1 Check status (should be uninitialized)

```powershell
vault status
```

If `Initialized: false`, run init.

### 2.2 Initialize and capture keys/token

```powershell
$init = vault operator init -key-shares=1 -key-threshold=1 -format=json | ConvertFrom-Json
$unsealKey = $init.unseal_keys_b64[0]
$rootToken = $init.root_token
```

(Optional) Save to file:

```powershell
$init | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 .\server-init.json
```

### 2.3 Unseal

```powershell
vault operator unseal $unsealKey
```

### 2.4 Login as root

```powershell
vault login $rootToken
```

Now verify:

```powershell
vault status
```

> If you restart the container later: you may need to unseal again with the same unseal key.

---

# Credential Storage Service (static KV v2 + access control + audit)

These steps work in **both dev mode and server mode**.

## 1) Enable audit logging (file)

This writes to a file inside the container bind-mounted to `docker\vault\logs\vault-audit.log`.

```powershell
vault audit enable file file_path=/vault/logs/vault-audit.log
vault audit list
```

---

## 2) Enable KV v2 for application credentials

```powershell
vault secrets enable -path=app-secrets -version=2 kv
vault secrets list
```

---

## 3) Store and retrieve a credential (T1)

```powershell
vault kv put -mount=app-secrets payments/stripe api_key="secret_api_key" account="demo-account"
vault kv get -mount=app-secrets payments/stripe
```

---

## 4) KV v2 versioning + rollback concept (T2)

Update creates a new version:

```powershell
vault kv put -mount=app-secrets payments/stripe api_key="NEW_secret_api_key"
```

Metadata shows versions and timestamps:

```powershell
vault kv metadata get -mount=app-secrets payments/stripe
```

Read back version 1:

```powershell
vault kv get -mount=app-secrets -version=1 payments/stripe
```

(Optional) Soft delete + undelete:

```powershell
vault kv delete -mount=app-secrets payments/stripe
vault kv undelete -mount=app-secrets -versions=2 payments/stripe
```

---

# Policy + Identity tests (T3)

## 1) Write least-privilege policy (only one secret path)

The policy file lives here:

* `.\docker\vault\policies\app-cred-policy.hcl`

Apply and verify:

```powershell
vault policy write app-cred-policy .\docker\vault\policies\app-cred-policy.hcl
vault policy read app-cred-policy
```

List policies:

```powershell
vault policy list
```

---

## 2) Enable userpass and create a restricted identity

```powershell
vault auth enable userpass
vault auth list
vault path-help auth/userpass
```

Create a user:

```powershell
vault write auth/userpass/users/payments-app password="matteo_password" policies="app-cred-policy"
```

---

## 3) Login as restricted user and test access

```powershell
vault login -method=userpass username=payments-app
# Password: matteo_password
```

Allowed (should succeed):

```powershell
vault kv get -mount=app-secrets payments/stripe
```

Denied (should fail):

```powershell
vault kv get -mount=app-secrets payments/other-service
```

List capabilities:

```powershell
vault token capabilities app-secrets/data/payments/stripe
vault token capabilities app-secrets/data/payments/other-service
```

---

# Token lifecycle tests (T4)

Back as root/operator (if you are still logged in as payments-app, login as root again).

## Create a short-lived token

```powershell
$tok = vault token create -ttl=2m -policy=app-cred-policy -format=json | ConvertFrom-Json
$short = $tok.auth.client_token
```

Lookup / renew / revoke:

```powershell
vault token lookup $short
vault token renew $short
vault token revoke $short
```

---

# Vault UI (quick visual)

Open:

* UI: [http://127.0.0.1:8200/ui](http://127.0.0.1:8200/ui)



---

# Audit evidence (T6)

The audit file is bind-mounted:

* Host path: `docker\vault\logs\vault-audit.log`
* Container path: `/vault/logs/vault-audit.log`

Open it in VS Code and search for:

* `app-secrets`
* `auth/userpass`
* `sys/audit`

You should see requests recorded for the operations you performed.

---

# Bonus: Minimal HTTP API calls (PowerShell)

Everything the CLI does is also possible via the HTTP API.

## 1) Check seal status (no auth required)

```powershell
Invoke-RestMethod -Method Get -Uri "$env:VAULT_ADDR/v1/sys/seal-status"
```

## 2) Read a secret via API (requires token)

Set token env var first:

```powershell
$env:VAULT_TOKEN = "<YOUR_TOKEN>"
```

KV v2 read endpoint format:

* `/v1/<mount>/data/<path>`

Example:

```powershell
Invoke-RestMethod -Method Get -Uri "$env:VAULT_ADDR/v1/app-secrets/data/payments/stripe" -Headers @{ "X-Vault-Token" = $env:VAULT_TOKEN }
```

---

# WORK IN PROGRESS...
# Optional: Dynamic DB credentials (T5) with PostgreSQL

## 0) Start the stack with Postgres

```powershell
docker compose -f docker\docker-compose.server-db.yml up -d
```

Follow the **SERVER MODE** init/unseal/login steps if needed.

## 1) Enable database secrets engine

```powershell
vault secrets enable database
```

## 2) Configure the Postgres connection

```powershell
vault write database/config/postgres `
  plugin_name=postgresql-database-plugin `
  allowed_roles=readonly `
  connection_url="postgresql://{{username}}:{{password}}@vault-postgres:5432/demo?sslmode=disable" `
  username="vaultadmin" `
  password="vaultadminpw"
```

## 3) Create a dynamic role (short TTL)

```powershell
$sql = @"
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT USAGE ON SCHEMA public TO "{{name}}";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO "{{name}}";
"@

vault write database/roles/readonly `
    db_name=postgres `
    creation_statements="$sql" `
    default_ttl=1m `
    max_ttl=10m


```

## 4) Request dynamic credentials and observe the lease

```powershell
$creds = vault read -format=json database/creds/readonly | ConvertFrom-Json
$lease = $creds.lease_id
$dbUser = $creds.data.username
$dbPass = $creds.data.password

Write-Host "Lease: $lease  User: $dbUser"
```

## 5) Revoke the lease (immediate deprovision)

```powershell
vault lease revoke $lease
```

> You can optionally test DB login from inside the postgres container (`psql`) to prove the user exists and then is revoked.

---
---

# Cleanup Docker containers

Stop dev mode:

```powershell
docker compose -f docker\docker-compose.dev.yml down
```

Stop server mode:

```powershell
docker compose -f docker\docker-compose.server.yml down
```

Stop server+db:

```powershell
docker compose -f docker\docker-compose.server-db.yml down
```


