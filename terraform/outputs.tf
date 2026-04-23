output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "frontend_asg_name" {
  description = "Check this in the console to find the Public IP of the Bastion Host."
  value       = aws_autoscaling_group.frontend.name
}

output "backend_private_ip" {
  description = "Private IP of the Backend. Needed for Ansible inventory."
  value       = aws_instance.backend.private_ip
}

output "database_private_ip" {
  description = "Private IP of the Database. Needed for Ansible inventory."
  value       = aws_instance.database.private_ip
}