output "Project_Name" {
  value = random_id.project_name.hex
}

output "Connect_to_Bastion" {
  value = "ssh -i ${var.ssh_key_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "Jump_through_Bastion" {
  value = "ssh -i ${var.ssh_key_name}.pem -L 8200:${aws_lb.vault.dns_name}:8200 ubuntu@${aws_instance.bastion.public_ip}"
}
