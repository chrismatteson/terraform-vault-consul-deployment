# AWS Cluster Installation

The code in this repositiory stands up a single Vault and Consul cluster on AWS
according to best practices outlined by Chris Matteson's Reference Architecture
Plus.

## Examples

The examples folder includes two more complicated solutions which take advantage
of this repository to stand up three clusters connected via either VPC peering
or Transit Gateways along with a bastion host.

## Todo:

There are numerous things left to be implimented to get this code to be fully
compliant with "Reference Architecture Plus"

1) TLS encryption on Consul should be configured for all services.
2) Client TLS certificates should be configured
3) ACLs should be created with less privilage and assigned to:
- Servers
- Clients
- Operator
4) Retry logic added into install scripts for things which I've seen timeout:
- Getting lock on package system
- Downloading binaries
5) Error handling logic as part of ASG health check and userdata to ensure a
node either presents as healthy or is killed and recreated.
6) System Manager logging into CloudWatch Logs
7) CloudTrail Events -> CloudWatch Alarms for:
- Changes to Launch Configuration userdata (could be modified to allow remote access)
- Changes to IAM permissions for:
 - EC2 instances (could be modified to allow SSM console login)
 - Unseal Key
 - Secure Setup Bucket
 - Secure Setup Bucket Key
 - 
- Accessing to items in Secure Setup Bucket (Would be good to not alarm for ec2 instances in autoscale groups)
8) CloudWatch Monitors/Configure Telemetry
