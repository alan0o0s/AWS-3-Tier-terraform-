output "rds_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance."
  value       = aws_db_instance.this.endpoint
}

output "rds_address" {
  description = "Hostname of the RDS instance (without port)."
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "Port the RDS instance listens on."
  value       = aws_db_instance.this.port
}

output "rds_identifier" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.this.id
}
