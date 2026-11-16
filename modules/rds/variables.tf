variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "private_db_subnet_ids" {
  description = "IDs of the private database subnets."
  type        = list(string)
}

variable "db_sg_id" {
  description = "ID of the database security group."
  type        = string
}

variable "db_engine" {
  description = "Database engine (postgres or mysql)."
  type        = string
}

variable "db_engine_version" {
  description = "Engine version. Leave null to use the AWS default for the engine."
  type        = string
  default     = null
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_name" {
  description = "Name of the initial database."
  type        = string
}

variable "db_username" {
  description = "Master username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password."
  type        = string
  sensitive   = true
}

variable "storage_size" {
  description = "Allocated storage (GiB)."
  type        = number
}

variable "max_storage_size" {
  description = "Upper bound (GiB) for storage autoscaling."
  type        = number
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
}

variable "multi_az" {
  description = "Whether to deploy in Multi-AZ mode."
  type        = bool
}

variable "enable_deletion_protection" {
  description = "Whether to enable RDS deletion protection."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on destroy."
  type        = bool
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
