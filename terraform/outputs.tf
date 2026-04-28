output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# ─── BASTION ───────────────────────────────────────────────────────────────────
output "bastion_public_ip" {
  description = "Public IP of Bastion Host - use this for SSH"
  value       = module.bastion.instance_public_ip
}

# ─── VOTE ──────────────────────────────────────────────────────────────────────
output "vote_private_ip" {
  description = "Private IP of Vote instance"
  value       = module.vote.instance_private_ip
}

# ─── RESULT ────────────────────────────────────────────────────────────────────
output "result_private_ip" {
  description = "Private IP of Result instance"
  value       = module.result.instance_private_ip
}

# ─── BACKEND ───────────────────────────────────────────────────────────────────
output "backend_private_ip" {
  description = "Private IP of Backend instance - Redis + Worker"
  value       = module.backend.instance_private_ip
}

# ─── DATABASE ──────────────────────────────────────────────────────────────────
output "database_private_ip" {
  description = "Private IP of Database instance - PostgreSQL"
  value       = module.database.instance_private_ip
}

# ─── ALB ───────────────────────────────────────────────────────────────────────
output "alb_dns_name" {
  description = "ALB DNS - use this to access the app"
  value       = aws_lb.main.dns_name
}

output "vote_app_url" {
  description = "URL for the Vote app"
  value       = "http://${aws_lb.main.dns_name}/vote"
}

output "result_app_url" {
  description = "URL for the Result app"
  value       = "http://${aws_lb.main.dns_name}/result"
}

