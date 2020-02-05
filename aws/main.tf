provider "aws" {
  region = var.region
}

resource "random_id" "project_name" {
  byte_length = 4
}

# Local for tag to attach to all items
locals {
  tags = merge(
    var.tags,
    {
      "ProjectName" = random_id.project_name.hex
    },
  )
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "bastion_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${random_id.project_name.hex}-bastion"

  cidr = "10.1.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0]]
  private_subnets = ["10.1.1.0/24"]
  public_subnets  = ["10.1.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Name = "overridden-name-public"
  }

  tags = local.tags

  vpc_tags = {
    Name = "${random_id.project_name.hex}-vpc"
  }
}

resource "aws_default_security_group" "bastion_default" {
  vpc_id = module.bastion_vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.latest-image.id
  instance_type = "t2.micro"
  subnet_id     = module.bastion_vpc.public_subnets[0]
  key_name      = var.ssh_key_name

  tags = local.tags
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${random_id.project_name.hex}-vpc"

  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Name = "overridden-name-public"
  }

  tags = local.tags

  vpc_tags = {
    Name = "${random_id.project_name.hex}-vpc"
  }
}

resource "aws_default_security_group" "vpc_default" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_default_security_group.bastion_default.id]
  }

  ingress {
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [aws_default_security_group.bastion_default.id]
  }

  ingress {
    from_port       = 8500
    to_port         = 8500
    protocol        = "tcp"
    security_groups = [aws_default_security_group.bastion_default.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_peering_connection" "bastion_connectivity" {
  peer_vpc_id = module.bastion_vpc.vpc_id
  vpc_id      = module.vpc.vpc_id
  auto_accept = true
}

resource "aws_route" "vpc" {
  count                     = length(module.bastion_vpc.public_subnets_cidr_blocks)
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = element(module.bastion_vpc.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity.id
}

resource "aws_route" "bastion_vpc" {
  count                     = length(module.vpc.public_subnets_cidr_blocks)
  route_table_id            = module.bastion_vpc.public_route_table_ids[0]
  destination_cidr_block    = element(module.vpc.public_subnets_cidr_blocks, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_connectivity.id
}


# AWS S3 Bucket for Certificates, Private Keys, Encryption Key, and License
resource "aws_kms_key" "bucketkms" {
  description             = "${random_id.project_name.hex}-key"
  deletion_window_in_days = 7
  # Add deny all policy to kms key to ensure accessing secrets
  # is a break-glass proceedure
  #  policy                  = "arn:aws:iam::aws:policy/AWSDenyAll"
  lifecycle {
    create_before_destroy = true
  }
  tags = local.tags
}

resource "aws_s3_bucket" "consul_setup" {
  bucket        = "${random_id.project_name.hex}-consul-setup"
  acl           = "private"
  force_destroy = var.force_bucket_destroy
  lifecycle {
    create_before_destroy = true
  }
  tags = local.tags
}

# AWS S3 Bucket for Consul Backups
resource "aws_s3_bucket" "consul_backups" {
  count         = var.consul_ent_license != "" ? 1 : 0
  bucket        = "${random_id.project_name.hex}-consul-backups"
  force_destroy = var.force_bucket_destroy
  lifecycle {
    create_before_destroy = true
  }
  tags = local.tags
}

# Create IAM policy to allow Consul to reach S3 bucket and KMS key
data "aws_iam_policy_document" "consul_bucket" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.consul_setup.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.consul_setup.arn
    ]
  }
}

resource "aws_iam_role_policy" "consul_bucket" {
  name   = "${random_id.project_name.id}-consul-bucket"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.consul_bucket.json
}

data "aws_iam_policy_document" "bucketkms" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    resources = [
      "${aws_kms_key.bucketkms.arn}"
    ]
  }
}

resource "aws_iam_role_policy" "bucketkms" {
  name   = "${random_id.project_name.id}-bucketkms"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.bucketkms.json
}

# Create IAM policy to allow Consul backups to reach S3 bucket
data "aws_iam_policy_document" "consul_backups" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.consul_backups[0].arn}/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucketVersions",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.consul_backups[0].arn]
  }
}

resource "aws_iam_role_policy" "consul_backups" {
  name   = "${random_id.project_name.id}-consul-backups"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.consul_backups.json
}

# Lookup most recent AMI
data "aws_ami" "latest-image" {
  most_recent = true
  owners      = var.ami_filter_owners

  filter {
    name   = "name"
    values = var.ami_filter_name
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "lambda" {
  source                = "github.com/chrismatteson/terraform-lambda"
  function_name         = "${random_id.project_name.hex}-consul-license"
  source_files          = [{ content = "install_license.py", filename = "install_license.py" }]
  environment_variables = { "LICENSE" = var.consul_ent_license }
  handler               = "install_license.lambda_handler"
  subnet_ids            = module.vpc.public_subnets
  security_group_ids    = [module.vpc.default_security_group_id]
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${random_id.project_name.id}-instance_profile"
  role        = aws_iam_role.instance_role.name

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = "${random_id.project_name.id}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.instance_role.json

  # aws_iam_instance_profile.instance_profile in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "auto-discover-cluster"
  role   = aws_iam_role.instance_role.name
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}

module "compress_consul" {
  source   = "github.com/chrismatteson/terraform-compress-userdata"
  filename = "userdata.sh"
  shell    = "bash"
  content = templatefile("${path.module}/install-consul.tpl",
    {
      consul_version                      = var.consul_version,
      consul_download_url                 = var.consul_download_url,
      consul_path                         = var.consul_path,
      consul_user                         = var.consul_user,
      ca_path                             = var.ca_path,
      cert_file_path                      = var.cert_file_path,
      key_file_path                       = var.key_file_path,
      server                              = var.server,
      client                              = var.client,
      config_dir                          = var.config_dir,
      data_dir                            = var.data_dir,
      systemd_stdout                      = var.systemd_stdout,
      systemd_stderr                      = var.systemd_stderr,
      bin_dir                             = var.bin_dir,
      cluster_tag_key                     = var.cluster_tag_key,
      cluster_tag_value                   = "${random_id.project_name.hex}-${var.cluster_tag_value}",
      datacenter                          = var.datacenter,
      autopilot_cleanup_dead_servers      = var.autopilot_cleanup_dead_servers,
      autopilot_last_contact_threshold    = var.autopilot_last_contact_threshold,
      autopilot_max_trailing_logs         = var.autopilot_max_trailing_logs,
      autopilot_server_stabilization_time = var.autopilot_server_stabilization_time,
      autopilot_redundancy_zone_tag       = var.autopilot_redundancy_zone_tag,
      autopilot_disable_upgrade_migration = var.autopilot_disable_upgrade_migration,
      autopilot_upgrade_version_tag       = var.autopilot_upgrade_version_tag,
      enable_gossip_encryption            = var.enable_gossip_encryption,
      enable_rpc_encryption               = var.enable_rpc_encryption,
      environment                         = var.environment,
      recursor                            = var.recursor,
      bucket                              = aws_s3_bucket.consul_setup.id,
      bucketkms                           = aws_kms_key.bucketkms.id,
      consul_license_arn                  = var.consul_ent_license != "" ? module.lambda.arn : "",
      enable_acls                         = var.enable_acls,
      enable_consul_http_encryption       = var.enable_consul_http_encryption,
      consul_backup_bucket                = aws_s3_bucket.consul_backups[0].id,
    },
  )
}

module "consul" {
  source            = "terraform-aws-modules/autoscaling/aws"
  version           = "3.4.0"
  image_id          = var.ami_id != "" ? var.ami_id : data.aws_ami.latest-image.id
  name              = "${random_id.project_name.hex}-consul"
  health_check_type = "EC2"
  max_size          = var.consul_cluster_size
  min_size          = var.consul_cluster_size
  desired_capacity  = var.consul_cluster_size
  instance_type     = "t2.small"
  #  vpc_id                      = module.vpc.vpc_id
  vpc_zone_identifier = module.vpc.public_subnets
  key_name            = var.ssh_key_name
  #  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  #  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
  enabled_metrics      = ["GroupTotalInstances"]
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  tags = concat(
    [
      for k, v in local.tags :
      {
        key : k
        value : v
        propagate_at_launch : true
      }
    ],
    [
      {
        key                 = var.cluster_tag_key
        value               = "${random_id.project_name.hex}-${var.cluster_tag_value}"
        propagate_at_launch = true
      }
    ]
  )
  user_data = module.compress_consul.userdata
}

resource "aws_iam_role_policy_attachment" "SystemsManager" {
  role       = aws_iam_role.instance_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "invoke_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [module.lambda.arn]
  }
}

resource "aws_iam_role_policy" "InvokeLambda" {
  name   = "${random_id.project_name.id}-invoke-lambda"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.invoke_lambda.json
}

# Install Vault
module "compress_vault" {
  source   = "github.com/chrismatteson/terraform-compress-userdata"
  filename = "userdata.sh"
  shell    = "bash"
  content = templatefile("${path.module}/install-vault.tpl",
    {
      consul_version                = var.consul_version,
      consul_download_url           = var.consul_download_url,
      vault_version                 = var.vault_version,
      vault_download_url            = var.vault_download_url,
      consul_path                   = var.consul_path,
      vault_path                    = var.vault_path,
      consul_user                   = var.consul_user,
      vault_user                    = var.vault_user,
      ca_path                       = var.ca_path,
      cert_file_path                = var.cert_file_path,
      key_file_path                 = var.key_file_path,
      server                        = var.server,
      client                        = var.client,
      config_dir                    = var.config_dir,
      data_dir                      = var.data_dir,
      systemd_stdout                = var.systemd_stdout,
      systemd_stderr                = var.systemd_stderr,
      bin_dir                       = var.bin_dir,
      cluster_tag_key               = var.cluster_tag_key,
      cluster_tag_value             = "${random_id.project_name.hex}-${var.cluster_tag_value}",
      datacenter                    = var.datacenter,
      enable_gossip_encryption      = var.enable_gossip_encryption,
      enable_rpc_encryption         = var.enable_rpc_encryption,
      environment                   = var.environment,
      recursor                      = var.recursor,
      bucket                        = aws_s3_bucket.consul_setup.id,
      bucketkms                     = aws_kms_key.bucketkms.id,
      consul_license_arn            = var.consul_ent_license != "" ? module.lambda.arn : "",
      enable_acls                   = var.enable_acls,
      enable_consul_http_encryption = var.enable_consul_http_encryption,
      consul_backup_bucket          = aws_s3_bucket.consul_backups[0].id,
    },
  )
}

module "vault" {
  source            = "terraform-aws-modules/autoscaling/aws"
  version           = "3.4.0"
  image_id          = var.ami_id != "" ? var.ami_id : data.aws_ami.latest-image.id
  name              = "${random_id.project_name.hex}-vault"
  health_check_type = "EC2"
  max_size          = var.vault_cluster_size
  min_size          = var.vault_cluster_size
  desired_capacity  = var.vault_cluster_size
  instance_type     = "t2.small"
  target_group_arns = [aws_lb_target_group.vault.arn]
  #  vpc_id                      = module.vpc.vpc_id
  vpc_zone_identifier = module.vpc.public_subnets
  key_name            = var.ssh_key_name
  #  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  #  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
  enabled_metrics      = ["GroupTotalInstances"]
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  tags = [
    for k, v in local.tags :
    {
      key : k
      value : v
      propagate_at_launch : true
    }
  ]
  user_data = module.compress_vault.userdata
}

resource "aws_lb" "vault" {
  name               = "${random_id.project_name.hex}-vault-lb"
  internal           = true
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "vault" {
  name     = "${random_id.project_name.hex}-vault-lb"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check {
    enabled = true
    path    = "/ui/"
  }
}

resource "aws_lb_listener" "vault" {
  load_balancer_arn = aws_lb.vault.arn
  port              = "8200"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}
