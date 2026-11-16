locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }

  # Map the chosen engine to its default port, used by security groups & RDS module.
  db_port = var.db_engine == "postgres" ? 5432 : 3306
}
