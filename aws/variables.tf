variable "region" { default = "us-east-1" }
variable "prefix" { default = "" }
variable "ssh_key_name" { default = "" }
variable "consul_cluster_size" { default = 5 }
variable "vault_cluster_size" { default = 3 }
variable "ami_id" { default = "" }
variable "ami_filter_owners" {
  description = "When bash install method, use a filter to lookup an image owner and name. Common combinations are 206029621532 and amzn2-ami-hvm* for Amazon Linux 2 HVM, and 099720109477 and ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-* for Ubuntu 18.04"
  type        = list(string)
  default     = ["099720109477"]
}
variable "ami_filter_name" {
  description = "When bash install method, use a filter to lookup an image owner and name. Common combinations are 206029621532 and amzn2-ami-hvm* for Amazon Linux 2 HVM, and 099720109477 and ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-* for Ubuntu 18.04"
  type        = list(string)
  default     = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
}
variable "vpc_id" { default = "" }
variable "subnet_ids" { default = "" }
variable "consul_ent_license" { default = "" }
variable "vault_ent_license" { default = "" }
variable "consul_version" {
  default = "1.6.3"
}
variable "consul_download_url" { default = "" }
variable "vault_version" {
  default = "1.3.2"
}
variable "vault_download_url" { default = "" }
variable "cluster_tag_key" { default = "consul-servers" }
variable "cluster_tag_value" { default = "auto-join" }
variable "consul_path" { default = "" }
variable "vault_path" { default = "" }
variable "consul_user" { default = "" }
variable "vault_user" { default = "" }
variable "ca_path" { default = "" }
variable "cert_file_path" { default = "" }
variable "key_file_path" { default = "" }
variable "server" { default = true }
variable "client" { default = false }
variable "config_dir" { default = "" }
variable "data_dir" { default = "" }
variable "systemd_stdout" { default = "" }
variable "systemd_stderr" { default = "" }
variable "bin_dir" { default = "" }
variable "datacenter" { default = "" }
variable "autopilot_cleanup_dead_servers" { default = "" }
variable "autopilot_last_contact_threshold" { default = "" }
variable "autopilot_max_trailing_logs" { default = "" }
variable "autopilot_server_stabilization_time" { default = "" }
variable "autopilot_redundancy_zone_tag" { default = "az" }
variable "autopilot_disable_upgrade_migration" { default = "" }
variable "autopilot_upgrade_version_tag" { default = "" }
variable "enable_gossip_encryption" { default = true }
variable "gossip_encryption_key" { default = "" }
variable "enable_rpc_encryption" { default = true }
variable "environment" { default = "" }
variable "recursor" { default = "" }
variable "tags" {
  description = "Map of extra tags to attach to items which accept them"
  type        = map(string)
  default     = {}
}
variable "enable_acls" { default = true }
variable "force_bucket_destroy" {
  description = "Boolean to force destruction of s3 buckets"
  default     = false
  type        = bool
}
variable "enable_consul_http_encryption" { default = false }
variable "enable_deletion_protection" { default = true }
