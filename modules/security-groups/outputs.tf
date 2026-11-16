output "alb_sg_id" {
  description = "ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID of the application (EC2) security group."
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "ID of the database (RDS) security group."
  value       = aws_security_group.db.id
}
