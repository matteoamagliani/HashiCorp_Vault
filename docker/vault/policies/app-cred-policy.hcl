# app-cred-policy.hcl
# Least-privilege access to ONE credential path in KV v2.
path "app-secrets/data/payments/stripe" {
  capabilities = ["read", "create", "update"]
}

path "app-secrets/metadata/payments/stripe" {
  capabilities = ["read"]
}
