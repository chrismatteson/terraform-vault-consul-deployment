output "Cluster_Name" {
  value = random_id.cluster_name.hex
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

output "route_tables" {
  value = module.vpc.public_route_table_ids
}

output "security_group_id" {
  value = module.vpc.default_security_group_id
}

output "vault_load_balancer" {
  value = aws_lb.vault.dns_name
}
