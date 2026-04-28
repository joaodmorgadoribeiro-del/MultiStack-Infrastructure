output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_ids[0]
}

output "private_subnet_backend_id" {
  value = module.vpc.private_subnet_ids[0]
}

output "private_subnet_db_id" {
  value = module.vpc.private_subnet_ids[1]
}

output "frontend_public_ip" {
  value = module.frontend.instance_public_ip
}

output "backend_private_ip" {
  value = module.backend.instance_private_ip
}

output "database_private_ip" {
  value = module.database.instance_private_ip
}

output "vote_app_url" {
  value = "http://${module.frontend.instance_public_ip}:5000"
}

output "result_app_url" {
  value = "http://${module.frontend.instance_public_ip}:4000"
}