# Example to deploy 3 environments with vpc peering

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

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "random_id" "project_tag" {
  byte_length = 4
}

# Local for tag to attach to all items
locals {
  tags = merge(
    var.tags,
    {
      "ProjectTag" = random_id.project_tag.hex
    },
  )
}

resource "local_file" "private_key" {
  sensitive_content = tls_private_key.ssh.private_key_pem
  filename          = "${path.module}/${random_id.project_tag.hex}-key.pem"
  file_permission   = "0400"
}

data "aws_availability_zones" "available" {
  provider = aws.region1
  state    = "available"
}

module "bastion_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${random_id.project_tag.hex}-bastion"

  cidr = "192.168.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0]]
  private_subnets = ["192.168.1.0/24"]
  public_subnets  = ["192.168.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    Name = "overridden-name-public"
  }

  tags = local.tags

  vpc_tags = {
    Name = "${random_id.project_tag.hex}-vpc"
  }
  providers = {
    aws = aws.region1
  }
}

resource "aws_default_security_group" "bastion_default" {
  provider = aws.region1
  vpc_id   = module.bastion_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "key" {
  provider   = aws.region1
  key_name   = "${random_id.project_tag.hex}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Lookup most recent AMI
data "aws_ami" "latest-image" {
  provider    = aws.region1
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  provider      = aws.region1
  ami           = data.aws_ami.latest-image.id
  instance_type = "t2.micro"
  subnet_id     = module.bastion_vpc.public_subnets[0]
  key_name      = aws_key_pair.key.key_name

  tags = local.tags
}

module "primary_cluster" {
  source                     = "../../"
  consul_version             = "1.6.3+ent"
  vault_version              = "1.3.2+ent"
  consul_cluster_size        = 6
  vault_cluster_size         = 3
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "0"
  force_bucket_destroy       = true
  tags                       = local.tags
  providers = {
    aws = aws.region1
  }
}

module "dr_cluster" {
  source                     = "../../"
  consul_version             = "1.6.3+ent"
  vault_version              = "1.3.2+ent"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "1"
  force_bucket_destroy       = true
  tags                       = local.tags
  providers = {
    aws = aws.region2
  }
}

module "eu_cluster" {
  source                     = "../../"
  consul_version             = "1.6.3+ent"
  vault_version              = "1.3.2+ent"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
  subnet_second_octet        = "2"
  force_bucket_destroy       = true
  tags                       = local.tags
  providers = {
    aws = aws.region3
  }
}

resource "aws_vpc_peering_connection" "bastion_connectivity" {
  provider    = aws.region1
  peer_vpc_id = module.bastion_vpc.vpc_id
  vpc_id      = module.primary_cluster.vpc_id
  auto_accept = true
}

resource "aws_vpc_peering_connection" "bastion_connectivity_dr" {
  provider    = aws.region2
  peer_vpc_id = module.bastion_vpc.vpc_id
  vpc_id      = module.dr_cluster.vpc_id
  auto_accept = false
  peer_region = var.region1
}

resource "aws_vpc_peering_connection_accepter" "bastion_connectivity_dr" {
  provider                  = aws.region1
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection" "bastion_connectivity_eu" {
  provider    = aws.region3
  peer_vpc_id = module.bastion_vpc.vpc_id
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
  provider    = aws.region3
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

resource "aws_security_group" "primary_cluster" {
  provider = aws.region1
  vpc_id   = module.primary_cluster.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = concat(module.dr_cluster.public_subnets_cidr_blocks, module.eu_cluster.public_subnets_cidr_blocks)
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }
}

resource "aws_security_group" "dr_cluster" {
  provider = aws.region2
  vpc_id   = module.dr_cluster.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = module.primary_cluster.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }
}

resource "aws_security_group" "eu_cluster" {
  provider = aws.region3
  vpc_id   = module.eu_cluster.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = module.primary_cluster.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = module.bastion_vpc.public_subnets_cidr_blocks
  }
}

resource "aws_route" "bastion_vpc" {
  provider                  = aws.region1
  count                     = length(module.primary_cluster.public_subnets_cidr_blocks)
  route_table_id            = module.bastion_vpc.default_route_table_id
  destination_cidr_block    = element(module.primary_cluster.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity.id
}

resource "aws_route" "bastion_vpc_dr" {
  provider                  = aws.region1
  count                     = length(module.dr_cluster.public_subnets_cidr_blocks)
  route_table_id            = module.bastion_vpc.default_route_table_id
  destination_cidr_block    = element(module.dr_cluster.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
}

resource "aws_route" "bastion_vpc_eu" {
  provider                  = aws.region1
  count                     = length(module.eu_cluster.public_subnets_cidr_blocks)
  route_table_id            = module.bastion_vpc.default_route_table_id
  destination_cidr_block    = element(module.eu_cluster.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
}

resource "aws_route" "vpc_bastion" {
  provider                  = aws.region1
  count                     = length(module.bastion_vpc.public_subnets_cidr_blocks)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.bastion_vpc.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity.id
}

resource "aws_route" "vpc_bastion_dr" {
  provider                  = aws.region2
  count                     = length(module.bastion_vpc.public_subnets_cidr_blocks)
  route_table_id            = module.dr_cluster.route_table
  destination_cidr_block    = element(module.bastion_vpc.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_dr.id
}

resource "aws_route" "vpc_bastion_eu" {
  provider                  = aws.region3
  count                     = length(module.bastion_vpc.public_subnets_cidr_blocks)
  route_table_id            = module.eu_cluster.route_table
  destination_cidr_block    = element(module.bastion_vpc.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity_eu.id
}

resource "aws_route" "vault_vpc_dr" {
  provider                  = aws.region1
  count                     = length(module.dr_cluster.public_subnets_cidr_blocks)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.dr_cluster.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
}

resource "aws_route" "vault_vpc_eu" {
  provider                  = aws.region1
  count                     = length(module.eu_cluster.public_subnets_cidr_blocks)
  route_table_id            = module.primary_cluster.route_table
  destination_cidr_block    = element(module.eu_cluster.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
}

resource "aws_route" "vpc_vault_dr" {
  provider                  = aws.region2
  count                     = length(module.primary_cluster.public_subnets_cidr_blocks)
  route_table_id            = module.dr_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_dr.id
}

resource "aws_route" "vpc_vault_eu" {
  provider                  = aws.region3
  count                     = length(module.primary_cluster.public_subnets_cidr_blocks)
  route_table_id            = module.eu_cluster.route_table
  destination_cidr_block    = element(module.primary_cluster.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.vault_connectivity_eu.id
}
