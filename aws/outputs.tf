output "Connect_to_Bastion" {
  value = "ssh -i ${var.ssh_key_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "Jump_through_Bastion" {
  value = "ssh -i ${var.ssh_key_name}.pem -L <local port>:<remote internal ip>:<remote port> ${aws_instance.bastion.public_ip}"
}
