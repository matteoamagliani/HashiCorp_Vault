# HashiCorp - Vault Demo

This repository is a **hands-on demonstration of HashiCorp Vault** as a **credentials storage service** (static secrets + access control)..

It combines:
- **Fast practice** with **Dev mode** (in-memory, auto-unsealed, fixed root token)
- A **more realistic setup** with **Server mode** (file storage, explicit init + unseal, persistent data)

It also demonstrates:
- **Static credentials** via **KV v2** (versioning, rollback, soft delete/undelete)
- **Authentication** via `userpass` (simple demo identity)
- **Policies (ACL)** for least privilege access control
- **Audit logging** to a file (demo evidence)
- *(Optional)* **Dynamic DB credentials** via PostgreSQL (database secrets engine)

> ⚠️ Dev mode is insecure and must **not** be used in production. Server mode here is still a lab setup (simplified).

---

## What is Vault?

HashiCorp Vault is a **secrets management** and **encryption** platform that provides:
- Secure storage of secrets (API keys, tokens, passwords, certificates)
- Fine-grained access control (policies)
- Multiple auth methods (tokens, username/password, OIDC, etc.)
- Audit logging
- Secret engines (KV, PKI, database, transit, and more)

Core architecture: **client–server**
- The **Vault server** stores/encrypts secrets and enforces policies.
- The **Vault CLI** (or HTTP API/UI) is a client that communicates with the server.

Docs:
- What is Vault: https://developer.hashicorp.com/vault/docs/about-vault/what-is-vault
- How Vault works / why use it: https://developer.hashicorp.com/vault/docs/about-vault/how-vault-works

---

## Deployment options (conceptual)

This lab focuses on **local Docker** deployments, but in real scenarios you may use:

- **HCP Vault Dedicated** (managed Vault on HashiCorp Cloud Platform)  
  https://developer.hashicorp.com/vault/tutorials/get-started-hcp-vault-dedicated

- **Self-managed Vault** (server mode, integrated storage / file / raft / etc.)

In this repo we will run:
- **Local Vault (Dev mode)** 
- **Local Vault (Server mode)** 
---

## Requirements (Windows)

- **Docker Desktop** (with Docker Compose v2)
- **VS Code**
- **Conda** (Miniconda/Anaconda) — optional helpers
- **Vault CLI** (`vault.exe`) installed and in `PATH`
  - Install: https://developer.hashicorp.com/vault/install#windows

> You can run `vault` inside the container too, but for this lab:  **Windows Vault CLI**.

---

## Quick start

### 1) (Optional) Create the conda environment
```powershell
conda env create -f conda\environment.yml
conda activate vault-lab
```

### 2) Start Vault (choose one)

#### Option A — Dev mode (fastest)

```powershell
docker compose -f docker\docker-compose.dev.yml up -d
```

Then follow `docs\cli.md` → **DEV MODE** section.

#### Option B — Server mode (realistic)

```powershell
docker compose -f docker\docker-compose.server.yml up -d
```

Then follow `docs\cli.md` → **SERVER MODE** section (init/unseal + login).

#### Optional — Server + PostgreSQL (dynamic DB creds demo)

```powershell
docker compose -f docker\docker-compose.server-db.yml up -d
```

Then follow `docs\cli.md` → **Dynamic DB credentials** section.

---

## Demo Flow

1. Start Vault (dev mode first, then server mode).
2. Show `vault status` and explain **sealed/unsealed** and **initialized/uninitialized**.
3. Enable **audit logging** and show the audit file receives events.
4. Enable **KV v2** at `app-secrets/`, store and retrieve a credential.
5. Show KV v2 **versioning** and **rollback** (read version 1).
6. Create a least-privilege policy and a demo identity (`userpass`).
7. Login as restricted user and show **allowed vs denied** reads.
8. Token lifecycle: create short TTL token, renew, revoke.
9. (Optional) DB secrets engine: issue dynamic DB user with TTL; revoke lease.

---

## Vault UI

Vault includes a built-in web UI:

* UI: [http://127.0.0.1:8200/ui](http://127.0.0.1:8200/ui)
* Seal status (API): [http://127.0.0.1:8200/v1/sys/seal-status](http://127.0.0.1:8200/v1/sys/seal-status)


## Notes 

* Server mode data persists under `docker\vault\file\` (bind-mounted volume).
* Audit log is written to `docker\vault\logs\vault-audit.log`.

For full step-by-step commands, see: **docs/cli.md**


## Project layout

```
vault-demo-realistic-refactored/
  conda/
    environment.yml
  docker/
    docker-compose.dev.yml
    docker-compose.server.yml
    docker-compose.server-db.yml        # optional: adds postgres for dynamic creds tests
    vault/
      config/vault.hcl
      policies/
        app-cred-policy.hcl
        kv-access-policy.hcl
        db-readonly-policy.hcl
      sql/
        postgres-init.sql               # optional sample DB objects
  docs/
    cli.md                              # step-by-step commands in PowerShell (Vault CLI)
  scripts/
    ps1/
      00-env.ps1
      01-dev-lab.ps1
      02-server-init-unseal.ps1
      03-credential-service-setup.ps1
      04-tests.ps1
      05-db-setup.ps1                   # optional dynamic DB creds tests
```







# HashiCorp Vault – Basic Demonstration

This repository contains notes, examples, and configurations for a **basic demonstration of HashiCorp Vault**, covering CLI usage, authentication methods, policies, secrets engines, and the Vault UI.

---

## Prerequisites

* Windows OS
* Vault CLI installed and available in `PATH`

---

## Installation

1. Download Vault for Windows from:
   [https://developer.hashicorp.com/vault/install#windows](https://developer.hashicorp.com/vault/install#windows)

2. Unzip the archive (Vault is distributed as a single binary).

3. Ensure the `vault` binary is available in your system `PATH`:
   [https://developer.hashicorp.com/vault/docs/get-vault/install-binary](https://developer.hashicorp.com/vault/docs/get-vault/install-binary)

---

## Deployment Options

You can run Vault in two different ways:

* **HashiCorp Cloud Platform (HCP) – Vault Dedicated**
  [https://developer.hashicorp.com/vault/tutorials/get-started-hcp-vault-dedicated/why-use-hcp-vault](https://developer.hashicorp.com/vault/tutorials/get-started-hcp-vault-dedicated/why-use-hcp-vault)

* **Local Vault (Dev Mode)** *(used in this repository)*

---

## 1. HCP Vault Dedicated

Official tutorial:
[https://developer.hashicorp.com/vault/tutorials/get-started-hcp-vault-dedicated](https://developer.hashicorp.com/vault/tutorials/get-started-hcp-vault-dedicated)

---

## 2. Local Vault (Dev Mode)

Vault Foundations tutorial:
[https://developer.hashicorp.com/vault/tutorials/get-started](https://developer.hashicorp.com/vault/tutorials/get-started)

### Scenario

* **Danielle** is a developer working on applications and plugins that interact with Vault. She uses a local Vault dev server for development and testing.
* **Oliver** is part of the operations team and evaluates both a self-managed Vault server and HCP Vault Dedicated for user acceptance testing.

Vault follows a **client–server architecture**:

* The Vault server manages secrets and storage backends.
* The Vault CLI communicates with the server over a TLS connection.

---

## Start Vault (Windows)

Run Vault in dev mode:

```powershell
vault server -dev -dev-root-token-id root -dev-tls
```

In a **second terminal**, configure the environment:

```powershell
$env:VAULT_ADDR="https://127.0.0.1:8200"
$env:VAULT_CACERT="C:\Users\matteo\AppData\Local\Temp\vault-tlsXXXXX\vault-ca.pem"
```

Verify the server:

```powershell
vault status
vault login
```

Use `root` as the token.

---

## Learn the Vault CLI

Command syntax:

```text
vault <command> [options] [path] [args]
```

Examples:

```powershell
vault status --help | Select-Object -First 20
vault status -format=json
vault token --help
```

---

## Enable and Configure Authentication

Enable the `userpass` auth method:

```powershell
vault auth enable userpass
vault auth list
vault path-help /auth/userpass
```

Vault enables auth methods under `/auth/`.
The `userpass` method is available at `/auth/userpass`.

---

## Move or Create the dicrectory where we want to save an ACL Policy

In my case: #TODO 


Move to a working directory:

```powershell
cd $env:USERPROFILE\Documents
notepad developer-vault-policy.hcl
```

Policy definition:

```hcl
path "dev-secrets/+/creds" {
  capabilities = ["create", "list", "read", "update"]
}
```

Apply the policy:

```powershell
vault policy write developer-vault-policy developer-vault-policy.hcl
```

---

## Create a User

```powershell
vault write auth/userpass/users/danielle-vault-user `
  password="Flyaway Cavalier Primary Depose" `
  policies=developer-vault-policy
```

---

## Enable Secrets Engine

List existing engines:

```powershell
vault secrets list
```

Enable a **KV v2** secrets engine:

```powershell
vault secrets enable -path=dev-secrets -version=2 kv
```

---

## Authenticate and Manage Secrets

Login using `userpass`:

```powershell
vault login -method=userpass username=danielle-vault-user
```

Store a secret:

```powershell
vault kv put dev-secrets/creds api-key=E6BED968-0FE3-411E-9B9B-C45812E4737A
```

Retrieve the secret:

```powershell
vault kv get dev-secrets/creds
```

---

## Vault UI

Vault includes a built-in web UI.

Open your browser and navigate to:

* UI: [https://127.0.0.1:8200/ui](https://127.0.0.1:8200/ui)
* Seal status: [https://127.0.0.1:8200/v1/sys/seal-status](https://127.0.0.1:8200/v1/sys/seal-status)

Accept the self-signed certificate warning.

### Explore the UI

1. Log in using the `root` token.
2. Enable and configure auth methods.
3. Create and manage ACL policies.
4. Inspect secrets engines and stored secrets.

---

## Vault HTTP API

The same operations can be performed using the Vault HTTP API.
*(Work in progress – TODO)*

---

## Repository Structure

```
configs/   # Vault configuration files
scripts/   # Helper scripts
docs/      # Documentation and notes
```

---
