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

## Dynamic Database Credentials - MySQL Database Secrets Engine
Reference: [MySQL Database Secrets Engine](https://www.vaultproject.io/docs/secrets/databases/mssql/)

Prior to the Vault Enterprise implementation, ACME Corporation's website and ERP application relied on static credentials to connect to an RDS MySQL database. These credentials were scheduled for rotation during a downtime window every three months. Sometimes these downtime windows were missed, leading to back-to-back weeks of downtime windows. Furthermore, the static credentials being valid for three months also created a large window of of opportunity for a malicious actor to retrieve them and use them without authorization.

Use of Vault's Database Secrets Engine allows for the ERP and Website application to request dynamic database credentials from Vault with the help of [Vault Agent](https://www.vaultproject.io/docs/agent/): the agent performs [auto-auth](https://www.vaultproject.io/docs/agent/autoauth/) to the primary Vault cluster using the [EC2 Authentication Method](https://www.vaultproject.io/docs/auth/aws/). Then, a template declaration in the Vault Agent configuration references the secret path for the MySQL Database Secrets Engine. Vault Agent will request this secret from Vault, causing Vault to create a temporary user and password for MySQL for the length of the lease's period, revoking it once the lease has expired.

## Database Encryption - Transit Secrets Engine
Reference: [Transit Secrets Engine](https://www.vaultproject.io/docs/secrets/transit/index.html)

## EU Data Protection - Mount Filters
Reference: [Mount Filters](https://www.vaultproject.io/guides/operations/mount-filter/)

## Systems Access Management - SSH Secrets Engine
Reference: [SSH Secrets Engine](https://www.vaultproject.io/docs/secrets/ssh/index.html)

## Applying the Terraform configuration

Ensure that a `stable.tfvars` file exists, with the following keys set:

```
vault_ent_license="[ENTER VAULT ENT LICENSE HERE]"
consul_ent_license="[ENTER CONSUL ENT LICENSE HERE]"
```

Then, ensure you are passing the `stable.tfvars` file when performing a `terraform apply`:

```
terraform apply -var-file=stable.tfvars
```

## Accessing Provisioned Consul and Vault Instances

The provisioned EC2 Instances are pre-configured with the [AWS Systems Manager Agent (SSM Agent)](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html), and thus a secure shell can be accessed without using an SSH keypair, from the [SSM managed instances console](https://console.aws.amazon.com/systems-manager/managed-instances).
