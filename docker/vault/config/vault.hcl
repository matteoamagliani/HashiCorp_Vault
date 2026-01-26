ui = true
disable_mlock = true

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# For a simple local demo we avoid TLS and HA config.
# In production, enable TLS, configure HA storage, and harden the deployment.
