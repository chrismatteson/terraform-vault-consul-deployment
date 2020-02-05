# Example to deploy 5 environments

variable "consul_ent_license" {}

module "primary_cluster" {
  source                     = "../"
  region                     = "us-east-1"
  consul_cluster_size        = 6
  vault_cluster_size         = 3
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
}

module "dr_cluster" {
  source                     = "../"
  region                     = "us-west-2"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
}

module "eu_cluster" {
  source                     = "../"
  region                     = "eu-central-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
}

module "eu_dr_cluster" {
  source                     = "../"
  region                     = "eu-west-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
}

module "ap_cluster" {
  source                     = "../"
  region                     = "ap-southeast-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  enable_deletion_protection = false
}
