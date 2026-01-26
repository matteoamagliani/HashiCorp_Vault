
# Vault CLI  - (Windows PowerShell)  

This guide is designed for **Windows** using **PowerShell**, **Vault CLI**, and **Docker**.

## CLI basics 

Command syntax:
```text
vault <command> [options] [path] [args]
````

Useful discovery commands:

```powershell
PS> vault status --help | Select-Object -First 30
PS> vault token --help
PS> vault secrets --help
PS> vault auth --help
```

---

## Common setup

### Verify Vault CLI

```powershell
PS> vault version
```

### Set the Vault address (HTTP for local lab)

```powershell
PS> $env:VAULT_ADDR = "http://127.0.0.1:8200"
```

### TLS setup (when you start Vault with -dev-tls)

If you start Vault locally with TLS (**example below**), the server generates a self-signed CA cert in your Temp folder like:

`%TEMP%\vault-tlsXXXXX\vault-ca.pem`

To make the Vault CLI trust it, set `VAULT_CACERT`.

In my case the dicrectory will be: 
```powershell
PS> $env:VAULT_CACERT="C:\Users\matteo\AppData\Local\Temp\vault-tlsXXXXX\vault-ca.pem"
```

**Current**:
$env:VAULT_CACERT="C:\Users\matteo\AppData\Local\Temp\vault-tls986829724\vault-ca.pem"

---

# A) DEV MODE - http

## A1) Start Vault dev server (Docker) 

```powershell
docker compose -f docker\docker-compose.dev.yml up -d
```

> Note: again, in this case we use HTTP (no TLS).
> The TLS flow above applies when you run `vault server -dev -dev-tls` on Windows.

## A2) Login as root (fixed token)

Dev mode uses a fixed root token set in compose: `dev-only-token`.

```powershell
vault login dev-only-token
```

## A3) Quick health/status

```powershell
vault status
```

We should see:

* `Sealed: false`
* `Storage Type: inmem`

## A4) Core secrets test (KV v2)

```powershell
vault secrets enable -path=app-secrets -version=2 kv
vault secrets list
vault kv put -mount=app-secrets payments/stripe api_key="secret_API_key" account="secret_account_info"

vault kv get -mount=app-secrets payments/stripe
```

Expected:

* `app-secrets/` shows in `vault secrets list`
* `kv get` prints your fields

---

## A5) Versioning + rollback (KV v2)

```powershell
vault kv put -mount=app-secrets payments/stripe api_key="NEW_secret_API_key"
vault kv metadata get -mount=app-secrets payments/stripe
vault kv get -mount=app-secrets -version=1 payments/stripe
```

Expected:

* metadata shows multiple versions
* version 1 shows old value

---

## A6) Policy + userpass + “allowed/denied”

### Write policy 

```powershell
vault policy write app-cred-policy .\docker\vault\policies\app-cred-policy.hcl
vault auth enable userpass
vault write auth/userpass/users/payments-app password="Pay_psw123" policies="app-cred-policy"
vault login -method=userpass username=payments-app
```

**Test**:
Now login as a root and create another secret:
```powershell
vault login 

PSW: dev-only-token
```

```powershell
vault kv put app-secrets/payments/other-service token=secret_token
```

```powershell
vault kv get -mount=app-secrets payments/stripe
vault kv get -mount=app-secrets payments/other-service
vault token capabilities app-secrets/data/payments/stripe
vault token capabilities app-secrets/data/payments/other-service
```

Expected:

* stripe succeeds
* other-service is denied
* capabilities show `read` only on the allowed path

---

## A7) Token lifecycle test

Back as root:

```powershell
vault login dev-only-token

$tok = vault token create -ttl=2m -policy=app-cred-policy -format=json | ConvertFrom-Json
$short = $tok.auth.client_token

vault token lookup $short
vault token renew $short
vault token revoke $short
```

Expected:

* lookup shows TTL
* renew extends TTL (if renewable)
* revoke makes token unusable

---

## A8) Audit evidence test

```powershell
vault audit enable file file_path=/vault/logs/vault-audit.log
vault audit list
```

Then open `docker\vault\logs\vault-audit.log` and search `app-secrets` / `auth/userpass`.

---
---
---

# B) DEV MODE - with TLS (https)

### B1) Start Vault (Terminal 1)

```powershell
vault server -dev -dev-root-token-id root -dev-tls
```

Leave it running.

### B2) Auto-find the CA cert + set env (Terminal 2)

This reliably finds the newest `vault-ca.pem` under `%TEMP%`:

```powershell
$ca = Get-ChildItem $env:TEMP -Directory -Filter "vault-tls*" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1 |
  ForEach-Object { Join-Path $_.FullName "vault-ca.pem" }

$env:VAULT_ADDR="https://127.0.0.1:8200"
$env:VAULT_CACERT=$ca

Write-Host "VAULT_CACERT=$env:VAULT_CACERT"
```

Now verify:

```powershell
vault status
vault login root
```

Expected:

* `Sealed: false`
* works without x509 errors

If you get **x509 unknown authority**: your `$env:VAULT_CACERT` is wrong (or the file doesn’t exist). Re-run the snippet and confirm the file exists:

```powershell
Test-Path $env:VAULT_CACERT
```

---

## B3) Learn CLI (safe discovery)

```powershell
vault status --help | Select-Object -First 20
vault status -format=json
vault token --help
```

---

## B4) Enable userpass

```powershell
vault auth enable userpass
vault auth list
vault path-help auth/userpass
```

---

## B5) Policy file (FIXED — your original has 2 issues)

### Why fix?

* Vault policies use `*` wildcards, **not `+`**
* KV v2 needs `/data/` and `/metadata/` paths in policies

Create `developer-vault-policy.hcl` like this:

```hcl
# Allow read/write the single secret "dev-secrets/creds"
path "dev-secrets/data/creds" {
  capabilities = ["create", "read", "update", "delete"]
}

# Allow reading metadata (useful for version info) and listing
path "dev-secrets/metadata/creds" {
  capabilities = ["read", "list"]
}
```

Apply it:

```powershell
vault policy write developer-vault-policy .\developer-vault-policy.hcl
vault policy read developer-vault-policy
```

---

## B6) Enable KV v2 + create user + test secrets

Enable KV v2:

```powershell
vault secrets enable -path=dev-secrets -version=2 kv
vault secrets list
```

Create user:

```powershell
vault write auth/userpass/users/matteo-vault-user `
  password="Matteo_uclm25" `
  policies="developer-vault-policy"
```

Login as user and test:

```powershell
vault login -method=userpass username=matteo-vault-user
vault kv put dev-secrets/creds api-key="E6BED968-0FE3-411E-9B9B-C45812E4737A"
vault kv get dev-secrets/creds
```

Expected:

* put/get works as restricted user (because policy allows exactly that path)

If I try another path:

```powershell
vault kv put dev-secrets/creds_not_allowed api-key="E6BED968-0FE3-411E-9B9B-C45812E4737A"
```
---

## B7) Vault UI (TLS)

Open:

* `https://127.0.0.1:8200/ui`

If the UI “doesn’t work”, do this quick triage:

* If the browser blocks the cert, proceed/accept (self-signed).

---

