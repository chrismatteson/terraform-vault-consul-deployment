variable "ami_id" { default = "" }
variable "ami_filter_owners" { 
  description = "When bash install method, use a filter to lookup an image owner and name. Common combinations are 206029621532 and amzn2-ami-hvm* for Amazon Linux 2 HVM, and 099720109477 and ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-* for Ubuntu 18.04"
  type    = list(string)
  default = ["099720109477"]
}
variable "ami_filter_name" {
  description = "When bash install method, use a filter to lookup an image owner and name. Common combinations are 206029621532 and amzn2-ami-hvm* for Amazon Linux 2 HVM, and 099720109477 and ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-* for Ubuntu 18.04"
  type    = list(string)
  default = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
}
variable "vpc_id" { default = "" }
variable "subnet_ids" { default = "" }
variable "consul_ent_license" { default = "" }
variable "vault_ent_license" { default = "" }
variable "consul_version" { default = "" }
variable "download-url" { default = "" }
variable "cluster_tag_key" { default = "consul-servers" }
variable "cluster_tag_value" { default = "auto-join" }
variable "path" { default = "/opt/consul" }
variable "user" { default = "" }
variable "ca-path" { default = "" }
variable "cert-file-path" { default = "" }
variable "key-file-path" { default = "" }
variable "server" { default = false }
variable "client" { default = false }
variable "config-dir" { default = "" }
variable "data-dir" { default = "" }
variable "systemd-stdout" { default = "" }
variable "systemd-stderr" { default = "" }
variable "bin-dir" { default = "" }
variable "datacenter" { default = "" }
variable "autopilot-cleanup-dead-servers" { default = "" }
variable "autopilot-last-contact-threshold" { default = "" }
variable "autopilot-max-trailing-logs" { default = "" }
variable "autopilot-server-stabilization-time" { default = "" }
variable "autopilot-redundancy-zone-tag" { default = "" }
variable "autopilot-disable-upgrade-migration" { default = "" }
variable "autopilot-upgrade-version-tag" { default = "" }
variable "enable-gossip-encryption" { default = false }
variable "gossip-encryption-key" { default = "" }
variable "enable-rpc-encryption" { default = false }
variable "environment" { default = "" }
variable "skip-consul-config" { default = "" }
variable "recursor" { default = "" }
variable "tags" {
  description = "List of extra tag blocks added to the autoscaling group configuration. Each element in the list is a map containing keys 'key', 'value', and 'propagate_at_launch' mapped to the respective values."
  type        = list(object({ key : string, value : string, propagate_at_launch : bool }))
  default     = []
}
