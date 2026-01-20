# HashiCorp Vault

This repository contains notes, examples, and configurations for HashiCorp Vault.


## Steps performed:

1. Install Vault from this link (Windows):
https://developer.hashicorp.com/vault/install#windows
2. Download the .zip file and unzip it. Is a simple binary file.
3. make sure the vault bianry is available on the PATH: 
https://developer.hashicorp.com/vault/docs/get-vault/install-binary

Now 2 options:
    - USE HashiCorp Cloud Platform (HCP) Vault Dedicated: 
    https://developer.hashicorp.com/vault/tutorials/get-started-hcp-vault-dedicated/why-use-hcp-vault
    - "PROCED LOCALLY".

## 1. HCP Vault Dedicated
https://developer.hashicorp.com/vault/tutorials/get-started-hcp-vault-dedicated

## 2. Local procedure
vault foundations:
https://developer.hashicorp.com/vault/tutorials/get-started

- After instalaltion (set up **dev server**):
https://developer.hashicorp.com/vault/tutorials/get-started/setup
### Scenario
Danielle is on the HashiCups development team, and builds the applications and plugins which interact with Vault. They have installed the Vault binary on their computer, and can now use a Vault development (dev mode) server for development and testing.

Oliver from the operations team evaluates a self-managed Vault server, and the HashiCorp Cloud Platform (HCP) Vault Dedicated server as solutions for local user acceptance testing.

Danielle and Oliver will start and prepare their Vault servers for use, check the server status, and use their initial root token to authenticate with Vault.

Vault operates as a client-server application. The Vault server is the sole piece of the Vault architecture that interacts with the data storage and backends. All operations done using the Vault CLI interact with the server over a TLS connection.

eSEGUIRE GLI STEPS (versione windows):
 1. Dopo: vault server -dev -dev-root-token-id root -dev-tls
 
 Another terminal:
 2.  $env:VAULT_ADDR="https://127.0.0.1:8200"
 3. $env:VAULT_CACERT="C:\Users\matteo\AppData\Local\Temp\vault-tls537602629/vault-ca.pem"
4. vault status 
5. vault login
6. Insert psw: root

Setup LAB: LEARN TO USE CLI

Equivalente di:
- vault status --help | head -n 12 
in windows:
- vault status --help | Select-Object -First 20

poi:
- vault status -format=json

### Understand the Vault CLI
The general command syntax is:

vault <command> [options] [path] [args]

- vault token --help

### Enable and configure an auth method
- vault auth --help
- vault auth enable userpass
NOW I HAVE ALSO ENBLED THE AUTH method using userpass. 
- vault auth list
I now have the token and the userpass methods.

By default, Vault enables all auth methods under the path /auth/. In this case, you enabled an instance of the userpass auth method at the path userpass/, so the fully qualified path to this auth method becomes /auth/userpass.

- vault path-help /auth/userpass


POI:
Mi spsoto in una mia directory:
- PS C:\WINDOWS\system32> cd $env:USERPROFILE\Documents
- notepad developer-vault-policy.hcl
salva il file con:
path "dev-secrets/+/creds" {
  capabilities = ["create", "list", "read", "update"]
}
- vault policy write developer-vault-policy developer-vault-policy.hcl

Creo nuova cartella e ripeto gli steps sopra:
 - mkdir $env:USERPROFILE\vault-lab
 - cd $env:USERPROFILE\vault-lab

POI:
- vault write auth/userpass/users/danielle-vault-user password="Flyaway Cavalier Primary Depose" policies=developer-vault-policy

- vault secret --help 
- vault secret list

A Vault server starts with some secrets engines enabled by default, including the cubbyhole, identity, and sys secrets engines. Since this is a dev server, Vault also enables a default instance of the key/value secrets engine, version 1

Enable a new instance of the version 2 key/value secrets engine, which features secret versioning at the path /dev-secret
- vault secrets enable -path=dev-secrets -version=2 kv

### Authenticate and create secret
Authenticate with Vault using the userpass auth method as danielle-vault-user:
- vault login -method=userpass username=danielle-vault-user
- password: Flyaway Cavalier Primary Depose

you can put a new secret in the secrets engine at the path /dev-secrets with the kv command.
- vault kv --help
- vault kv put /dev-secrets/creds api-key=E6BED968-0FE3-411E-9B9B-C45812E4737A
- vault kv get /dev-secrets/creds

## Learn to use the Vault UI
All editions of Vault include a web user interface (UI). In this tutorial you will assume the role of Oliver from the operations team who is going to configure Vault using the UI for Steve and the SRE team.

Open a web browser and navigate to https://127.0.0.1:8200. Accept the warning about self-signed certificates.

validate server status:
https://127.0.0.1:8200/v1/sys/seal-status

Navigate to the Vault login page at https://127.0.0.1:8200/ui.

All editions of Vault include the Vault UI. The Vault UI supports authenticating to Vault using supported auth methods such as userpass or oidc through an OIDC provider.

Because you are running Vault in dev mode, the UI is automatically enabled. This helps quickly start Vault for testing or development.

You can enable the UI using a Vault configuration file for more complex requirements. Add the ui parameter to the configuration file and set the value to true.

## Explore the VAULT UI
1. On the Vault login page (https://127.0.0.1:8200/ui) enter root in the Token field and click Sign In.
2. Oliver will use the Vault UI to enable and configure the userpass auth method for the SRE team, and create a Vault ACL policy to allow access to the k/v secrets engine.
3. Navigate to the main Vault dashboard at https://127.0.0.1:8200/ui/vault/dashboard and click Policies.

All the steps performed..

## Learn to use the Vault HTTP API



## Structure
- `configs/` – Vault configurations
- `scripts/` – Helper scripts
- `docs/` – documentations


## Usage
Work in progress...