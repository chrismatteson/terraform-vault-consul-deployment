output "Project_Name" {
  value = random_id.project_name.hex
}

output "Connect_to_Bastion" {
  value = length(aws_instance.bastion) > 0 ? "ssh -i ${var.bastion_ssh_key_name}.pem ubuntu@${aws_instance.bastion[0].public_ip}" : "No bastion created"
}

output "Jump_through_Bastion" {
  value = length(aws_instance.bastion) > 0 ?"ssh -i ${var.bastion_ssh_key_name}.pem -L 8200:${aws_lb.vault.dns_name}:8200 ubuntu@${aws_instance.bastion[0].public_ip}" : "No bastion created"
}

output "bastion_vpc_id" {
  value = module.bastion_vpc.vpc_id
}

output "bastion_public_subnets" {
  value = module.bastion_vpc.public_subnets_cidr_blocks
}

output "bastion_route_table" {
  value = module.bastion_vpc.public_route_table_ids[0]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets_cidr_blocks
}

output "route_table" {
  value = module.vpc.public_route_table_ids[0]
}

output "vault_load_balancer" {
  value = aws_lb.vault.dns_name
}
