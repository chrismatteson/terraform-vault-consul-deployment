output "Project_Name" {
  value = random_id.project_name.hex
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "public_subnets_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}
output "security_group_id" {
  value = module.vpc.default_security_group_id
}

output "vault_load_balancer" {
  value = aws_lb.vault.dns_name
}
