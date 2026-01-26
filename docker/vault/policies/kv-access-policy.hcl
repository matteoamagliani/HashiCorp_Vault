# kv-access-policy.hcl
# Example policy for the 'shared' KV v2 mount used in basic exercises.
path "shared/data/kv/creds" {
  capabilities = ["read", "create", "update", "delete"]
}
