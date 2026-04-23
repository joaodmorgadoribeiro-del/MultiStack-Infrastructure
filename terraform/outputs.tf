output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}


output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

output "database_private_ip" {
  value = aws_instance.database.private_ip
}