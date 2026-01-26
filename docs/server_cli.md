
# SERVER MODE 

## 1) Start Vault server mode (Docker)

```powershell
PS> docker compose -f docker\docker-compose.server.yml up -d
```

## 2) Initialize and unseal (first time only)

### 2.1 Check status (should be uninitialized)

```powershell
PS> vault status
```

If `Initialized: false`, run init.

### 2.2 Initialize and capture keys/token

```powershell
PS> $init = vault operator init -key-shares=1 -key-threshold=1 -format=json | ConvertFrom-Json
PS> $unsealKey = $init.unseal_keys_b64[0]
PS> $rootToken = $init.root_token
```

(Optional) Save to file (DO NOT do this in real production):

```powershell
PS> $init | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 .\server-init.json
```

### 2.3 Unseal

```powershell
PS> vault operator unseal $unsealKey
```

### 2.4 Login as root

```powershell
PS> vault login $rootToken
```

Now verify:

```powershell
PS> vault status
```

> If you restart the container later: you may need to unseal again with the same unseal key.

---

# Credential Storage Service (static KV v2 + access control + audit)

These steps work in **both dev mode and server mode**.

## 1) Enable audit logging (file)

This writes to a file inside the container bind-mounted to `docker\vault\logs\vault-audit.log`.

```powershell
PS> vault audit enable file file_path=/vault/logs/vault-audit.log
PS> vault audit list
```

---

## 2) Enable KV v2 for application credentials

```powershell
PS> vault secrets enable -path=app-secrets -version=2 kv
PS> vault secrets list
```

---

## 3) Store and retrieve a credential (T1)

```powershell
PS> vault kv put -mount=app-secrets payments/stripe api_key="sk_test_REPLACE_ME" account="demo-account"
PS> vault kv get -mount=app-secrets payments/stripe
```

---

## 4) KV v2 versioning + rollback concept (T2)

Update creates a new version:

```powershell
PS> vault kv put -mount=app-secrets payments/stripe api_key="sk_test_NEW_VALUE"
```

Metadata shows versions and timestamps:

```powershell
PS> vault kv metadata get -mount=app-secrets payments/stripe
```

Read back version 1:

```powershell
PS> vault kv get -mount=app-secrets -version=1 payments/stripe
```

(Optional) Soft delete + undelete:

```powershell
PS> vault kv delete -mount=app-secrets payments/stripe
PS> vault kv undelete -mount=app-secrets -versions=2 payments/stripe
```

---

# Policy + Identity tests (T3)

## 1) Write least-privilege policy (only one secret path)

The policy file lives here:

* `.\docker\vault\policies\app-cred-policy.hcl`

Apply and verify:

```powershell
PS> vault policy write app-cred-policy .\docker\vault\policies\app-cred-policy.hcl
PS> vault policy read app-cred-policy
```

(Optional) List policies:

```powershell
PS> vault policy list
```

---

## 2) Enable userpass and create a restricted identity

```powershell
PS> vault auth enable userpass
PS> vault auth list
PS> vault path-help auth/userpass
```

Create a user:

```powershell
PS> vault write auth/userpass/users/payments-app password="P@ss-demo-Only" policies="app-cred-policy"
```

---

## 3) Login as restricted user and test access

```powershell
PS> vault login -method=userpass username=payments-app
# Password: P@ss-demo-Only
```

Allowed (should succeed):

```powershell
PS> vault kv get -mount=app-secrets payments/stripe
```

Denied (should fail):

```powershell
PS> vault kv get -mount=app-secrets payments/other-service
```

Optional: explain with capabilities:

```powershell
PS> vault token capabilities app-secrets/data/payments/stripe
PS> vault token capabilities app-secrets/data/payments/other-service
```

---

# Token lifecycle tests (T4)

Back as root/operator (if you are still logged in as payments-app, login as root again).

## Create a short-lived token

```powershell
PS> $tok = vault token create -ttl=2m -policy=app-cred-policy -format=json | ConvertFrom-Json
PS> $short = $tok.auth.client_token
```

Lookup / renew / revoke:

```powershell
PS> vault token lookup $short
PS> vault token renew $short
PS> vault token revoke $short
```

---

# Vault UI (quick visual)

Open:

* UI: [http://127.0.0.1:8200/ui](http://127.0.0.1:8200/ui)

In the UI you can:

1. Log in (root token or userpass)
2. Inspect auth methods
3. Inspect policies
4. Browse secrets engines + KV v2 versions
5. Confirm audit events correspond to actions

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
PS> Invoke-RestMethod -Method Get -Uri "$env:VAULT_ADDR/v1/sys/seal-status"
```

## 2) Read a secret via API (requires token)

Set token env var first:

```powershell
PS> $env:VAULT_TOKEN = "<YOUR_TOKEN>"
```

KV v2 read endpoint format:

* `/v1/<mount>/data/<path>`

Example:

```powershell
PS> Invoke-RestMethod -Method Get -Uri "$env:VAULT_ADDR/v1/app-secrets/data/payments/stripe" -Headers @{ "X-Vault-Token" = $env:VAULT_TOKEN }
```

---

# Optional: Dynamic DB credentials (T5) with PostgreSQL

## 0) Start the stack with Postgres

```powershell
PS> docker compose -f docker\docker-compose.server-db.yml up -d
```

Follow the **SERVER MODE** init/unseal/login steps if needed.

## 1) Enable database secrets engine

```powershell
PS> vault secrets enable database
```

## 2) Configure the Postgres connection

```powershell
PS> vault write database/config/postgres `
  plugin_name=postgresql-database-plugin `
  allowed_roles=readonly `
  connection_url="postgresql://{{username}}:{{password}}@vault-postgres:5432/demo?sslmode=disable" `
  username="vaultadmin" `
  password="vaultadminpw"
```

## 3) Create a dynamic role (short TTL)

```powershell
PS> vault write database/roles/readonly `
  db_name=postgres `
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" `
  default_ttl=1m `
  max_ttl=10m
```

## 4) Request dynamic credentials and observe the lease

```powershell
PS> $creds = vault read -format=json database/creds/readonly | ConvertFrom-Json
PS> $lease = $creds.lease_id
PS> $dbUser = $creds.data.username
PS> $dbPass = $creds.data.password

PS> Write-Host "Lease: $lease  User: $dbUser"
```

## 5) Revoke the lease (immediate deprovision)

```powershell
PS> vault lease revoke $lease
```

> You can optionally test DB login from inside the postgres container (`psql`) to prove the user exists and then is revoked.

---

# Cleanup

Stop dev mode:

```powershell
PS> docker compose -f docker\docker-compose.dev.yml down
```

Stop server mode:

```powershell
PS> docker compose -f docker\docker-compose.server.yml down
```

Stop server+db:

```powershell
PS> docker compose -f docker\docker-compose.server-db.yml down
```

```
```
