output "Deployment_Tag" {
  value = random_id.deployment_tag.hex
}

output "Connect_to_Bastion" {
  value = "ssh -i ${aws_key_pair.key.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "Jump_through_Bastion_Primary" {
  value = "ssh -i ${aws_key_pair.key.key_name}.pem -L 8200:${module.primary_cluster.vault_load_balancer}:8200 ubuntu@${aws_instance.bastion.public_ip}"
}

output "Jump_through_Bastion_DR" {
  value = "ssh -i ${aws_key_pair.key.key_name}.pem -L 8200:${module.dr_cluster.vault_load_balancer}:8200 ubuntu@${aws_instance.bastion.public_ip}"
}

output "Jump_through_Bastion_EU" {
  value = "ssh -i ${aws_key_pair.key.key_name}.pem -L 8200:${module.eu_cluster.vault_load_balancer}:8200 ubuntu@${aws_instance.bastion.public_ip}"
}

