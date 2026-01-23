
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
