# Allow read/write the single secret "dev-secrets/creds"
path "dev-secrets/data/creds" {
  capabilities = ["create", "read", "update", "delete"]
}

# Allow reading metadata (useful for version info) and listing
path "dev-secrets/metadata/creds" {
  capabilities = ["read", "list"]
}