output "Project_Tag" {
  value = random_id.project_tag.hex
}

output "Connect_to_Bastion" {
  value = module.primary_cluster.Connect_to_Bastion
}

output "Jump_through_Bastion_Primary" {
  value = module.primary_cluster.Jump_through_Bastion
}

output "Jump_through_Bastion_DR" {
  value = "ssh -i ${aws_key_pair.key.key_name}.pem -L 8200:${module.dr_cluster.vault_load_balancer}:8200 ubuntu@${module.primary_cluster.bastion_ip}"
}

output "Jump_through_Bastion_EU" {
  value = "ssh -i ${aws_key_pair.key.key_name}.pem -L 8200:${module.eu_cluster.vault_load_balancer}:8200 ubuntu@${module.primary_cluster.bastion_ip}"
}

output "Flask_app" {
  value = "http://${aws_instance.web.public_ip}:8000"
}
