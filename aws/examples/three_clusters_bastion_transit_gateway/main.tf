# Example to deploy 5 environments

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
      "ProjectName" = random_id.project_tag.hex
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

# In a real world scenario, this resource most likely was pre-created for the existing infrastructure in the region
resource "aws_ec2_transit_gateway" "primary_gateway" {
  provider                       = aws.region1
  auto_accept_shared_attachments = "enable"
  tags                           = local.tags
}

resource "aws_ec2_transit_gateway_vpc_attachment" "bastion" {
  provider           = aws.region1
  subnet_ids         = module.bastion_vpc.public_subnets
  transit_gateway_id = aws_ec2_transit_gateway.primary_gateway.id
  vpc_id             = module.bastion_vpc.vpc_id

  tags = local.tags
}

resource "aws_ec2_transit_gateway_vpc_attachment" "primary" {
  provider           = aws.region1
  subnet_ids         = module.primary_cluster.public_subnets
  transit_gateway_id = aws_ec2_transit_gateway.primary_gateway.id
  vpc_id             = module.primary_cluster.vpc_id

  tags = local.tags
}

# In a real world scenario, this resource most likely was pre-created for the existing infrastructure in the region
resource "aws_ec2_transit_gateway" "dr_gateway" {
  provider                       = aws.region2
  auto_accept_shared_attachments = "enable"
  tags                           = local.tags
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dr_cluster" {
  provider           = aws.region2
  subnet_ids         = module.dr_cluster.public_subnets
  transit_gateway_id = aws_ec2_transit_gateway.dr_gateway.id
  vpc_id             = module.dr_cluster.vpc_id

  tags = local.tags
}

# In a real world scenario, this resource most likely was pre-created for the existing infrastructure in the region
resource "aws_ec2_transit_gateway" "eu_gateway" {
  provider                       = aws.region3
  auto_accept_shared_attachments = "enable"
  tags                           = local.tags
}

resource "aws_ec2_transit_gateway_vpc_attachment" "eu_cluster" {
  provider           = aws.region3
  subnet_ids         = module.eu_cluster.public_subnets
  transit_gateway_id = aws_ec2_transit_gateway.eu_gateway.id
  vpc_id             = module.eu_cluster.vpc_id

  tags = local.tags
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
