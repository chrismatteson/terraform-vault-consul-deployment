provider "aws" {
  region = "us-east-1"
}

resource "random_id" "project_name" {
  byte_length = 4
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${random_id.project_name.hex}"

  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  assign_generated_ipv6_cidr_block = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Name = "overridden-name-public"
  }

  tags = {
    Owner       = "cmatteson"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "${random_id.project_name.hex}-vpc"
  }
}

# Create Consul Encryption Key
resource "random_id" "gossip_encrypt_key" {
  byte_length = 16
  lifecycle {
    create_before_destroy = true
  }
}

# Create Consul CA Certificate
resource "tls_private_key" "private_key" {
  algorithm = "ECDSA"
  lifecycle {
    create_before_destroy = true
  }
}

resource "random_integer" "serial_number" {
  min     = 1000000000
  max     = 9999999999
  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.private_key.private_key_pem
  is_ca_certificate = true
  validity_period_hours = 43800

  subject {
    common_name = "Consul Agent CA ${random_integer.serial_number.result}${random_integer.serial_number.result}"
    country     = "US"
    postal_code = "94105"
    province    = "CA"
    locality    = "San Francisco"
    street_address = ["101 Second Street"]
    organization = "HashiCorp Inc."
  }
  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
  lifecycle {
    create_before_destroy = true
  }
}

# AWS S3 Bucket for Certificates, Private Keys, Encryption Key, and License
resource "aws_kms_key" "bucketkms" {
  description             = "${random_id.project_name.hex}-key"
  deletion_window_in_days = 7
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket" "consul-setup" {
  bucket = "${random_id.project_name.hex}-consul-setup"
  acl    = "private"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket_object" "gossip_encrypt_key" {
  key        = "gossip_encrypt_key"
  bucket     = aws_s3_bucket.consul-setup.id
  content    = random_id.gossip_encrypt_key.b64_std
  kms_key_id = aws_kms_key.bucketkms.arn
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket_object" "private_key" {
  key        = "ca_private_key.pem"
  bucket     = aws_s3_bucket.consul-setup.id
  content    = tls_private_key.private_key.private_key_pem
  kms_key_id = aws_kms_key.bucketkms.arn
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket_object" "ca_cert" {
  key        = "ca.pem"
  bucket     = aws_s3_bucket.consul-setup.id
  content    = tls_self_signed_cert.ca.cert_pem
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket_object" "consul_license" {
  count      = var.consul_ent_license != "" ? 1: 0
  key        = "ca.pem"
  bucket     = aws_s3_bucket.consul-setup.id
  content    = var.consul_ent_license
  kms_key_id = aws_kms_key.bucketkms.arn
  lifecycle {
    create_before_destroy = true
  }
}

# Lookup most recent AMI
data "aws_ami" "latest-image" {
most_recent = true
owners = var.ami_filter_owners

  filter {
      name   = "name"
      values = var.ami_filter_name
  }

  filter {
      name   = "virtualization-type"
      values = ["hvm"]
  }
}

module "consul" {
#  source                      = "hashicorp/consul/aws"
  source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.7.1"
  ami_id                      = var.ami_id != "" ? var.ami_id : data.aws_ami.latest-image.id
  cluster_name                = random_id.project_name.hex
  instance_type               = "t2.small"
  vpc_id                      = module.vpc.vpc_id
  subnet_ids                  = module.vpc.public_subnets
  ssh_key_name                = "chrismatteson-us-east-1"
  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
  user_data = templatefile("${path.module}/install-consul.tpl",
    {
      version                             = var.consul_version,
      download-url                        = var.download-url,
      path                                = var.path,
      user                                = var.user,
      ca-path                             = var.ca-path,
      cert-file-path                      = var.cert-file-path,
      key-file-path                       = var.key-file-path,
      server                              = var.server,
      client                              = var.client,
      config-dir                          = var.config-dir,
      data-dir                            = var.data-dir,
      systemd-stdout                      = var.systemd-stdout,
      systemd-stderr                      = var.systemd-stderr,
      bin-dir                             = var.bin-dir,
      cluster-tag-key                     = var.cluster_tag_key,
      cluster-tag-value                   = var.cluster_tag_value,
      datacenter                          = var.datacenter,
      autopilot-cleanup-dead-servers      = var.autopilot-cleanup-dead-servers,
      autopilot-last-contact-threshold    = var.autopilot-last-contact-threshold,
      autopilot-max-trailing-logs         = var.autopilot-max-trailing-logs,
      autopilot-server-stabilization-time = var.autopilot-server-stabilization-time,
      autopilot-redundancy-zone-tag       = var.autopilot-redundancy-zone-tag,
      autopilot-disable-upgrade-migration = var.autopilot-disable-upgrade-migration,
      autopilot-upgrade-version-tag       = var.autopilot-upgrade-version-tag,
      enable-gossip-encryption            = var.enable-gossip-encryption,
      enable-rpc-encryption               = var.enable-rpc-encryption,
      environment                         = var.environment,
      skip-consul-config                  = var.skip-consul-config,
      recursor                            = var.recursor,
      bucket				  = aws_s3_bucket.consul-setup.id,
      bucketkms                           = aws_kms_key.bucketkms.id,
      consul_ent_license                  = var.consul_ent_license,
    },
  )
}
