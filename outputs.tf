############################
# Networking
############################

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets."
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets."
  value       = module.vpc.private_db_subnet_ids
}

############################
# Load Balancer
############################

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer. Open this in a browser to test the app."
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Route53-compatible hosted zone ID of the ALB (useful for creating an alias record)."
  value       = module.alb.alb_zone_id
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group."
  value       = module.alb.target_group_arn
}

############################
# Compute
############################

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group."
  value       = module.compute.autoscaling_group_name
}

output "key_pair_name" {
  description = "Name of the generated AWS Key Pair used by the launch template."
  value       = module.compute.key_pair_name
}

output "private_key_path" {
  description = "Local path where the generated SSH private key was written. Keep this file secure; it is gitignored."
  value       = module.compute.private_key_path
}

############################
# Database
############################

output "rds_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance."
  value       = module.rds.rds_endpoint
}

output "rds_port" {
  description = "Port the RDS instance listens on."
  value       = module.rds.rds_port
}
