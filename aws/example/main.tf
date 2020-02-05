# Example to deploy 5 environments

provider "aws" {
  alias  = "sa-east-1"
  region = "sa-east-1"
}

provider "aws" {
  alias  = "ca-central-1"
  region = "ca-central-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "ap-southeast-1"
  region = "ap-southeast-1"
}

variable "consul_ent_license" {}

module "primary_cluster" {
  source                     = "../"
  region                     = "us-east-1"
  consul_cluster_size        = 6
  vault_cluster_size         = 3
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "0"
  force_bucket_destroy       = true
  create_bastion             = true
}

module "dr_cluster" {
  source                     = "../"
  region                     = "us-west-2"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "1"
  force_bucket_destroy       = true
  create_bastion             = false
}

module "eu_cluster" {
  source                     = "../"
  region                     = "eu-central-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "2"
  force_bucket_destroy       = true
  create_bastion             = false
}

module "eu_dr_cluster" {
  source                     = "../"
  region                     = "eu-west-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "3"
  force_bucket_destroy       = true
  create_bastion             = false
}

module "ap_cluster" {
  source                     = "../"
  region                     = "ap-southeast-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "4"
  force_bucket_destroy       = true
  create_bastion             = false
}

resource "aws_vpc_peering_connection" "bastion_connectivity_dr" {
  provider    = aws.us-west-2
  peer_vpc_id = module.primary_cluster.bastion_vpc_id
  vpc_id      = module.dr_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "bastion_connectivity_dr" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
  auto_accept               = true

}

resource "aws_vpc_peering_connection" "bastion_connectivity_eu" {
  provider    = aws.eu-central-1
  peer_vpc_id = module.primary_cluster.bastion_vpc_id
  vpc_id      = module.eu_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "bastion_connectivity_eu" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
  auto_accept               = true

}

resource "aws_vpc_peering_connection" "bastion_connectivity_eu_dr" {
  provider    = aws.eu-west-1
  peer_vpc_id = module.primary_cluster.bastion_vpc_id
  vpc_id      = module.eu_dr_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "bastion_connectivity_eu_dr" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu_dr.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection" "bastion_connectivity_ap" {
  provider    = aws.ap-southeast-1
  peer_vpc_id = module.primary_cluster.bastion_vpc_id
  vpc_id      = module.ap_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "bastion_connectivity_ap" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_ap.id
  auto_accept               = true

}

resource "aws_vpc_peering_connection" "vault_connectivity_dr" {
  provider    = aws.us-west-2
  peer_vpc_id = module.primary_cluster.vpc_id
  vpc_id      = module.dr_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "vault_connectivity_dr" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
  auto_accept               = true

}

resource "aws_vpc_peering_connection" "vault_connectivity_eu" {
  provider    = aws.eu-central-1
  peer_vpc_id = module.primary_cluster.vpc_id
  vpc_id      = module.eu_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "vault_connectivity_eu" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
  auto_accept               = true

}

resource "aws_vpc_peering_connection" "vault_connectivity_eu_dr" {
  provider    = aws.eu-west-1
  peer_vpc_id = module.primary_cluster.vpc_id
  vpc_id      = module.eu_dr_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "vault_connectivity_eu_dr" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu_dr.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection" "vault_connectivity_ap" {
  provider    = aws.ap-southeast-1
  peer_vpc_id = module.primary_cluster.vpc_id
  vpc_id      = module.ap_cluster.vpc_id
  auto_accept = false
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "vault_connectivity_ap" {
  provider                  = aws.us-east-1
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_ap.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection" "vault_connectivity_eu_eu_dr" {
  provider    = aws.eu-west-1
  peer_vpc_id = module.eu_cluster.vpc_id
  vpc_id      = module.eu_dr_cluster.vpc_id
  auto_accept = false
  peer_region = "eu-central-1"
}

resource "aws_vpc_peering_connection_accepter" "vault_connectivity_eu_eu_dr" {
  provider                  = aws.eu-central-1
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu_eu_dr.id
  auto_accept               = true
}

resource "aws_route" "bastion_vpc_dr" {
  provider                  = aws.us-east-1
  count                     = length(module.dr_cluster.public_subnets)
  route_table_id            = module.primary_cluster.bastion_route_table
  destination_cidr_block    = element(module.dr_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
}

resource "aws_route" "bastion_vpc_eu" {
  provider                  = aws.us-east-1
  count                     = length(module.eu_cluster.public_subnets)
  route_table_id            = module.primary_cluster.bastion_route_table
  destination_cidr_block    = element(module.eu_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
}

resource "aws_route" "bastion_vpc_eu_dr" {
  provider                  = aws.us-east-1
  count                     = length(module.eu_dr_cluster.public_subnets)
  route_table_id            = module.primary_cluster.bastion_route_table
  destination_cidr_block    = element(module.eu_dr_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu_dr.id
}

resource "aws_route" "bastion_vpc_ap" {
  provider                  = aws.us-east-1
  count                     = length(module.ap_cluster.public_subnets)
  route_table_id            = module.primary_cluster.bastion_route_table
  destination_cidr_block    = element(module.ap_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_ap.id
}

resource "aws_route" "vpc_bastion_dr" {
  provider                  = aws.us-west-2
  count                     = length(module.primary_cluster.bastion_public_subnets)
  route_table_id            = module.dr_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.bastion_public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
}

resource "aws_route" "vpc_bastion_eu" {
  provider                  = aws.eu-central-1
  count                     = length(module.primary_cluster.bastion_public_subnets)
  route_table_id            = module.eu_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.bastion_public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
}

resource "aws_route" "vpc_bastion_eu_dr" {
  provider                  = aws.eu-west-1
  count                     = length(module.primary_cluster.bastion_public_subnets)
  route_table_id            = module.eu_dr_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.bastion_public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu_dr.id
}

#resource "aws_route" "vpc_bastion_ap" {
#  provider                  = aws.us-east-1
#  count                     = length(module.primary_cluster.bastion_public_subnets)
#  route_table_id            = module.ap_cluster.route_table
#  destination_cidr_block    = element(module.primary_cluster.bastion_public_subnets, count.index)
#  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_ap.id
#}

resource "aws_route" "vault_vpc_dr" {
  provider                  = aws.us-east-1
  count                     = length(module.dr_cluster.public_subnets)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.dr_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
}

resource "aws_route" "vault_vpc_eu" {
  provider                  = aws.us-east-1
  count                     = length(module.eu_cluster.public_subnets)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.eu_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
}

resource "aws_route" "vault_vpc_eu_dr" {
  provider                  = aws.us-east-1
  count                     = length(module.eu_dr_cluster.public_subnets)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.eu_dr_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu_dr.id
}

#resource "aws_route" "vault_vpc_ap" {
#  provider                  = aws.us-east-1
#  count                     = length(module.ap_cluster.public_subnets)
#  route_table_id            = module.primary_cluster.bastion_route_table
#  destination_cidr_block    = element(module.ap_cluster.public_subnets, count.index)
#  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_ap.id
#}

resource "aws_route" "vpc_vault_dr" {
  provider                  = aws.us-west-2
  count                     = length(module.primary_cluster.public_subnets)
  route_table_id            = module.dr_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
}

resource "aws_route" "vpc_vault_eu" {
  provider                  = aws.eu-central-1
  count                     = length(module.primary_cluster.public_subnets)
  route_table_id            = module.eu_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
}

resource "aws_route" "vpc_vault_eu_dr" {
  provider                  = aws.eu-west-1
  count                     = length(module.primary_cluster.public_subnets)
  route_table_id            = module.eu_dr_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu_dr.id
}

resource "aws_route" "vpc_vault_ap" {
  provider                  = aws.ap-southeast-1
  count                     = length(module.primary_cluster.public_subnets)
  route_table_id            = module.ap_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_ap.id
}

resource "aws_route" "eu_eu_dr" {
  provider                  = aws.eu-central-1
  count                     = length(module.eu_dr_cluster.public_subnets)
  route_table_id            = module.eu_cluster.route_table
  destination_cidr_block    = element(module.eu_dr_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu_eu_dr.id
}

resource "aws_route" "eu_dr_eu" {
  provider                  = aws.eu-west-1
  count                     = length(module.eu_cluster.public_subnets)
  route_table_id            = module.eu_dr_cluster.route_table
  destination_cidr_block    = element(module.eu_cluster.public_subnets, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu_eu_dr.id
}
