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

Prior to the Vault Enterprise implementation, ACME Corporation's website and ERP application relied on static credentials to connect to an RDS database. These credentials were scheduled for rotation during a downtime window every three months. Sometimes these downtime windows were missed, leading to back-to-back weeks of downtime windows. Furthermore, the static credentials being valid for three months also created a large window of of opprotunity for a malicious actor to retrieve them and use them without authorization.

## Database Encryption - Transit Secrets Engine
Reference: [Transit Secrets Engine](https://www.vaultproject.io/docs/secrets/transit/index.html)

## EU Data Protection - Mount Filters
Reference: [Mount Filters](https://www.vaultproject.io/guides/operations/mount-filter/)

## Systems Access Management - SSH Secrets Engine
Reference: [SSH Secrets Engine](https://www.vaultproject.io/docs/secrets/ssh/index.html)

# Applying the Terraform configuration

Ensure that a `stable.tfvars` file exists, with the following keys set:

```
vault_ent_license="[ENTER VAULT ENT LICENSE HERE]"
consul_ent_license="[ENTER CONSUL ENT LICENSE HERE]"
```

Then, ensure you are passing the `stable.tfvars` file when performing a `terraform apply`:

```
terraform apply -var-file=stable.tfvars
```
