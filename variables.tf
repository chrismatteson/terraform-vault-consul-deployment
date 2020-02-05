# Supply the following two variables using a tfvars file
variable "consul_ent_license" {}
variable "vault_ent_license" {}

variable "force_bucket_destroy" {
  default     = true
  description = "Whether or not to force destroy s3 buckets that are non-empty."
}
