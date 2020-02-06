#!/bin/bash

# Ensure PRIMARY_VAULT_ADDR points to the Vault LB endpoint

vault write -f sys/replication/performance/primary/enable primary_cluster_addr=$PUBLIC_VAULT_ADDR
vault write sys/replication/performance/primary/secondary-token id=eu-performance
