vault auth enable userpass
vault write auth/userpass/users/demo \
  password="demo123" \
  policies="app-readonly"
