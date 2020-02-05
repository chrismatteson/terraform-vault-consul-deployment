module "primary_cluster" {
  source                     = "./modules/aws"
  region                     = "us-east-1"
  consul_cluster_size        = 6
  vault_cluster_size         = 3
  consul_ent_license         = var.consul_ent_license
  vault_ent_license          = var.vault_ent_license
  subnet_second_octet        = "0"
  enable_deletion_protection = false
}

module "dr_cluster" {
  source                     = "./modules/aws"
  region                     = "us-west-2"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  vault_ent_license          = var.vault_ent_license
  subnet_second_octet        = "1"
  enable_deletion_protection = false
}

module "eu_cluster" {
  source                     = "./modules/aws"
  region                     = "eu-central-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  vault_ent_license          = var.vault_ent_license
  subnet_second_octet        = "2"
  enable_deletion_protection = false
}

module "eu_dr_cluster" {
  source                     = "./modules/aws"
  region                     = "eu-west-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  vault_ent_license          = var.vault_ent_license
  subnet_second_octet        = "4"
  enable_deletion_protection = false
}

module "ap_cluster" {
  source                     = "./modules/aws"
  region                     = "ap-southeast-1"
  consul_cluster_size        = 1
  vault_cluster_size         = 1
  consul_ent_license         = var.consul_ent_license
  vault_ent_license          = var.vault_ent_license
  subnet_second_octet        = "4"
  enable_deletion_protection = false
}
