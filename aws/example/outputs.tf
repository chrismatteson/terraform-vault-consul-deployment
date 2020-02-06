output "Project_Tag" {
  value = random_id.project_tag.hex
}

output "Connect_to_Bastion" {
  value = module.primary_cluster.Connect_to_Bastion
}

output "Jump_through_Bastion" {
  value = module.primary_cluster.Jump_through_Bastion
}

output "Flask_app" {
  value = "http://${aws_instance.web.public_ip}:8000"
}
