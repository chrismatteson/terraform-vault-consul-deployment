provider "aws" {
}

resource "random_id" "cluster_name" {
  byte_length = 4
}

# Local for tag to attach to all items
locals {
  tags = merge(
    var.tags,
    {
      "ClusterName" = random_id.cluster_name.hex
    },
  )
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${random_id.cluster_name.hex}-vpc"

  cidr = "10.${var.subnet_second_octet}.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = [
    for num in range(0, length(data.aws_availability_zones.available.names)) :
    cidrsubnet("10.${var.subnet_second_octet}.1.0/16", 8, 1 + num)
  ]
  public_subnets = [
    for num in range(0, length(data.aws_availability_zones.available.names)) :
    cidrsubnet("10.${var.subnet_second_octet}.101.0/16", 8, 101 + num)
  ]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    Name = "overridden-name-public"
  }

  tags = local.tags

  vpc_tags = {
    Name = "${random_id.cluster_name.hex}-vpc"
    Purpose = "vault"
  }
}

# AWS S3 Bucket for Certificates, Private Keys, Encryption Key, and License
resource "aws_kms_key" "bucketkms" {
  description             = "${random_id.cluster_name.hex}-key"
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
  bucket        = "${random_id.cluster_name.hex}-consul-setup"
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
  bucket        = "${random_id.cluster_name.hex}-consul-backups"
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
  name   = "${random_id.cluster_name.id}-consul-bucket"
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
  name   = "${random_id.cluster_name.id}-bucketkms"
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
  name   = "${random_id.cluster_name.id}-consul-backups"
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
  function_name         = "${random_id.cluster_name.hex}-consul-license"
  source_files          = [{ content = "install_license.py", filename = "install_license.py" }]
  environment_variables = { "LICENSE" = var.consul_ent_license }
  handler               = "install_license.lambda_handler"
  subnet_ids            = module.vpc.public_subnets
  security_group_ids    = [module.vpc.default_security_group_id]
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${random_id.cluster_name.id}-instance_profile"
  role        = aws_iam_role.instance_role.name

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = "${random_id.cluster_name.id}-instance-role"
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

data "template_cloudinit_config" "consul" {
  gzip         = true
  base64_encode = true
  part {
    filename     = "install-consul.sh"
    content_type = "text/x-shellscript"
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
        cluster_tag_value                   = "${random_id.cluster_name.hex}-${var.cluster_tag_value}",
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
      }
    )
  }
}

module "consul" {
  source            = "terraform-aws-modules/autoscaling/aws"
  version           = "3.4.0"
  image_id          = var.ami_id != "" ? var.ami_id : data.aws_ami.latest-image.id
  name              = "${random_id.cluster_name.hex}-consul"
  health_check_type = "EC2"
  max_size          = var.consul_cluster_size
  min_size          = var.consul_cluster_size
  desired_capacity  = var.consul_cluster_size
  instance_type     = "t2.small"
  vpc_zone_identifier = module.vpc.public_subnets
  key_name            = var.ssh_key_name
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
        value               = "${random_id.cluster_name.hex}-${var.cluster_tag_value}"
        propagate_at_launch = true
      }
    ]
  )
  user_data = data.template_cloudinit_config.consul.rendered
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
  name   = "${random_id.cluster_name.id}-invoke-lambda"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.invoke_lambda.json
}

# Install Vault
data "template_cloudinit_config" "vault" {
  gzip         = true
  base64_encode = true
  part {
    filename     = "install-vault.sh"
    content_type = "text/x-shellscript"
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
      cluster_tag_value             = "${random_id.cluster_name.hex}-${var.cluster_tag_value}",
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
      kms_key                       = aws_kms_key.vault.id
      }
    )
  }
}

resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 10

  tags = {
    Name = "vault-kms-unseal-${random_id.cluster_name.hex}"
  }
}

data "aws_iam_policy_document" "vault-kms-unseal" {
  statement {
    sid       = "VaultKMSUnseal"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
  }
}

resource "aws_iam_role_policy" "kms_key" {
  name   = "${random_id.cluster_name.id}-kms-key"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.vault-kms-unseal.json
}

module "vault" {
  source            = "terraform-aws-modules/autoscaling/aws"
  version           = "3.4.0"
  image_id          = var.ami_id != "" ? var.ami_id : data.aws_ami.latest-image.id
  name              = "${random_id.cluster_name.hex}-vault"
  health_check_type = "EC2"
  max_size          = var.vault_cluster_size
  min_size          = var.vault_cluster_size
  desired_capacity  = var.vault_cluster_size
  instance_type     = "t2.small"
  target_group_arns = [aws_lb_target_group.vault.arn]
  vpc_zone_identifier = module.vpc.public_subnets
  key_name            = var.ssh_key_name
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
  user_data = data.template_cloudinit_config.vault.rendered
}

resource "aws_lb" "vault" {
  name               = "${random_id.cluster_name.hex}-vault-lb"
  internal           = true
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "vault" {
  name     = "${random_id.cluster_name.hex}-vault-lb"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check {
    interval          = "5"
    timeout           = "2"
    path              = "/v1/sys/seal-status"
    port              = "8200"
    protocol          = "HTTP"
    matcher           = "200,405"
    healthy_threshold = 2
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
