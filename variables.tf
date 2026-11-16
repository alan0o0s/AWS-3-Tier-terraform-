############################
# General / Project
############################

variable "project_name" {
  description = "Short name used to prefix and tag all resources."
  type        = string
  default     = "company-web-platform"
}

variable "environment" {
  description = "Deployment environment name (e.g. production, staging, dev)."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "dev"], var.environment)
    error_message = "environment must be one of: production, staging, dev."
  }
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "owner" {
  description = "Team or individual responsible for these resources (used for tagging)."
  type        = string
  default     = "DevOps"
}

############################
# Networking
############################

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy into. Leave empty to auto-select the first 2 AZs available in the region."
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Number of Availability Zones to use when availability_zones is not explicitly set."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2 for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

############################
# Compute / Auto Scaling
############################

variable "instance_type" {
  description = "EC2 instance type for the application servers."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group."
  type        = number
  default     = 6
}

variable "cpu_target" {
  description = "Target average CPU utilization (%) for the target-tracking scale-out policy."
  type        = number
  default     = 50
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization (%) below which the ASG is considered eligible to scale in. Documented for clarity; the target tracking policy manages both directions automatically around cpu_target."
  type        = number
  default     = 30
}

variable "enable_ssh" {
  description = "Whether to allow SSH (port 22) to application instances from ssh_allowed_cidr. SSM Session Manager is preferred and does not require this."
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into application instances, only used if enable_ssh is true."
  type        = string
  default     = "0.0.0.0/32"
}

variable "root_volume_size" {
  description = "Size (GiB) of the root EBS volume on application instances."
  type        = number
  default     = 40
}

############################
# Database
############################

variable "db_engine" {
  description = "Database engine to use (postgres or mysql)."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.db_engine)
    error_message = "db_engine must be either \"postgres\" or \"mysql\"."
  }
}

variable "db_engine_version" {
  description = "Database engine version. Leave null to use the AWS-default version for the chosen engine."
  type        = string
  default     = null
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the initial database created on the RDS instance."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "app_admin"
  sensitive   = true
}

variable "db_password" {
  description = <<-EOT
    Master password for the RDS instance. For a learning/demo project this is a
    sensitive Terraform variable (never hardcode it, pass it via TF_VAR_db_password,
    a .tfvars file excluded from Git, or a CI/CD secret store). For a real
    production system, prefer generating/rotating this via AWS Secrets Manager
    (see README "Secrets Management" section) instead of a Terraform variable.
  EOT
  type        = string
  sensitive   = true
}

variable "storage_size" {
  description = "Allocated storage (GiB) for the RDS instance."
  type        = number
  default     = 20
}

variable "max_storage_size" {
  description = "Upper bound (GiB) for RDS storage autoscaling. Set equal to storage_size to disable autoscaling."
  type        = number
  default     = 100
}

variable "backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "Whether to deploy the RDS instance in Multi-AZ mode for high availability."
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the RDS instance."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final RDS snapshot on destroy. Set to false for production."
  type        = bool
  default     = false
}
