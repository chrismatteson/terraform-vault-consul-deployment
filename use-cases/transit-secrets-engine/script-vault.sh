#!/bin/bash

vault secrets enable transit
vault write -f transit/keys/app-key

cat << EOF > /tmp/transit.hcl
path "transit/encrypt/app-key" {
  capabilities = ["update"]
}

path "transit/decrypt/app-key" {
  capabilities = ["update"]
}
EOF

vault policy write transit /tmp/transit.hcl
