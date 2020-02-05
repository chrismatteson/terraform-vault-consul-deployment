# ACME Corporation - Vault Enterprise Implementation

This implementation provisions multiple Vault Enterprise clusters over the following regions:

## Background

## Architecture 

| AWS Region        | Role                                  | Size (Consul/Vault)   | Notes                                               |
| ----------------- | ------------------------------------- | --------------------- | --------------------------------------------------- |
| us-west-1         | Primary                               | (6/3)                 |                                                     |
| us-west-2         | DR Replica of Primary                 | (1/1)*                |                                                     |
| eu-central-1      | Performance Replica                   | (1/1)*                | Contains EU PII-related database decryption keys**  |
| eu-west-1         | DR Replica of EU Performance Replica  | (1/1)*                | Contains EU PII-related database decryption keys**  |
| ap-southeast-1    | Performance Replica                   | (1/1)*                |                                                     |

## Dynamic Database Credentials - Postgresql Database Secrets Engine
Reference: [Postgresql Database Secrets Engine](https://www.vaultproject.io/docs/secrets/databases/postgresql/)

## Database Encryption - Transit Secrets Engine
Reference: [Transit Secrets Engine](https://www.vaultproject.io/docs/secrets/transit/index.html)

## EU Data Protection - Mount Filters
Reference: [Mount Filters](https://www.vaultproject.io/guides/operations/mount-filter/)

## Systems Access Management - SSH Secrets Engine
Reference: [SSH Secrets Engine](https://www.vaultproject.io/docs/secrets/ssh/index.html)
