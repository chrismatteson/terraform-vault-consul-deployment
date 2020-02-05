# Supply the following two variables using a tfvars file
variable "consul_ent_license" {}
variable "vault_ent_license" {}

variable "force_bucket_destroy" {
  default     = true
  description = "Whether or not to force destroy s3 buckets that are non-empty."
}

variable "consul_version" {
  default = "1.6.3+ent"
  description = "Which version of the consul binary to download from releases.hashicorp.com."
}

variable "vault_version" {
  default = "1.3.2+ent"
  description = "Which version of the vault binary to download from releases.hashicorp.com."
}
