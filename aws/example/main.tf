# Example to deploy 5 environments

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
}
