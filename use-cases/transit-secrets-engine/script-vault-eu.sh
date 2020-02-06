#!/bin/bash

vault secrets enable transit
vault write -f transit/keys/app-key-eu

cat << EOF > /tmp/transit-eu.hcl
path "transit/encrypt/app-key-eu" {
  capabilities = ["update"]
}

path "transit/decrypt/app-key-eu" {
  capabilities = ["update"]
}
EOF

vault policy write transit /tmp/transit-eu.hcl
