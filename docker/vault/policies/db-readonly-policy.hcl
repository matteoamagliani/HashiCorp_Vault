# db-readonly-policy.hcl
# Policy to allow reading dynamic database credentials from one role.
path "database/creds/readonly" {
  capabilities = ["read"]
}
