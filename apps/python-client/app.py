import hvac
import os

client = hvac.Client(
    url="http://127.0.0.1:8200",
    token=os.environ.get("VAULT_TOKEN")
)

secret = client.secrets.kv.v2.read_secret_version(
    path="api",
    mount_point="kv"
)

print("Retrieved secret:")
print(secret["data"]["data"])
