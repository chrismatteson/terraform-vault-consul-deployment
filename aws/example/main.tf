# Example to deploy 5 environments

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "region1"
  region = var.region1
}

provider "aws" {
  alias  = "region2"
  region = var.region2
}

provider "aws" {
  alias  = "region3"
  region = var.region3
}

provider "aws" {
  alias  = "region4"
  region = var.region5
}

provider "aws" {
  alias  = "region6"
  region = var.region6
}

provider "aws" {
  alias  = "region7"
  region = var.region7
}

provider "aws" {
  alias  = "region8"
  region = var.region8
}

provider "aws" {
  alias  = "region9"
  region = var.region9
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "private_key" {
  sensitive_content = tls_private_key.ssh.private_key_pem
  filename          = "${path.module}/${random_id.project_tag.hex}-key.pem"
  file_permission   = "0400"
}

resource "aws_key_pair" "key" {
  key_name   = "${random_id.project_tag.hex}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

module "primary_cluster" {
  source                     = "../"
  region                     = var.region1
  consul_cluster_size        = 6
  vault_cluster_size         = 3
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "0"
  force_bucket_destroy       = true
  create_bastion             = true
  bastion_ssh_key_name       = aws_key_pair.key.key_name
  providers = {
    aws = aws.region1
  }
}

module "dr_cluster" {
  source                     = "../"
  region                     = var.region2
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "1"
  force_bucket_destroy       = true
  create_bastion             = false
  providers = {
    aws = aws.region2
  }
}

module "eu_cluster" {
  source                     = "../"
  region                     = var.region7
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "2"
  force_bucket_destroy       = true
  create_bastion             = false
  providers = {
    aws = aws.region7
  }
}

resource "aws_vpc_peering_connection" "bastion_connectivity_dr" {
  provider    = aws.region2
  peer_vpc_id      = module.primary_cluster.bastion_vpc_id
  vpc_id = module.dr_cluster.vpc_id
  auto_accept = false
  peer_region = var.region1
}

resource "aws_vpc_peering_connection_accepter" "bastion_connectivity_dr" {
  provider                  = aws.region1
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection" "bastion_connectivity_eu" {
  provider    = aws.region7
  peer_vpc_id = module.primary_cluster.bastion_vpc_id
  vpc_id      = module.eu_cluster.vpc_id
  auto_accept = false
  peer_region = var.region1
}

resource "aws_vpc_peering_connection_accepter" "bastion_connectivity_eu" {
  provider                  = aws.region1
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection" "vault_connectivity_dr" {
  provider    = aws.region2
  peer_vpc_id = module.primary_cluster.vpc_id
  vpc_id      = module.dr_cluster.vpc_id
  auto_accept = false
  peer_region = var.region1
}

resource "aws_vpc_peering_connection_accepter" "vault_connectivity_dr" {
  provider                  = aws.region1
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection" "vault_connectivity_eu" {
  provider    = aws.region7
  peer_vpc_id = module.primary_cluster.vpc_id
  vpc_id      = module.eu_cluster.vpc_id
  auto_accept = false
  peer_region = var.region1
}

resource "aws_vpc_peering_connection_accepter" "vault_connectivity_eu" {
  provider                  = aws.region1
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
  auto_accept               = true
}

resource "aws_route" "bastion_vpc_dr" {
  provider                  = aws.region1
  count                     = length(module.dr_cluster.public_subnets)
  route_table_id            = module.primary_cluster.bastion_route_table
  destination_cidr_block    = element(module.dr_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
}

resource "aws_route" "bastion_vpc_eu" {
  provider                  = aws.region1
  count                     = length(module.eu_cluster.public_subnets)
  route_table_id            = module.primary_cluster.bastion_route_table
  destination_cidr_block    = element(module.eu_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
}

resource "aws_route" "vpc_bastion_dr" {
  provider                  = aws.region2
  count                     = length(module.primary_cluster.bastion_public_subnets)
  route_table_id            = module.dr_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.bastion_public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
}

resource "aws_route" "vpc_bastion_eu" {
  provider                  = aws.region7
  count                     = length(module.primary_cluster.bastion_public_subnets)
  route_table_id            = module.eu_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.bastion_public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
}

resource "aws_route" "vault_vpc_dr" {
  provider                  = aws.region1
  count                     = length(module.dr_cluster.public_subnets)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.dr_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
}

resource "aws_route" "vault_vpc_eu" {
  provider                  = aws.region1
  count                     = length(module.eu_cluster.public_subnets)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.eu_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
}

resource "aws_route" "vpc_vault_dr" {
  provider                  = aws.region2
  count                     = length(module.primary_cluster.public_subnets)
  route_table_id            = module.dr_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
}

resource "aws_route" "vpc_vault_eu" {
  provider                  = aws.region7
  count                     = length(module.primary_cluster.public_subnets)
  route_table_id            = module.eu_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
}
