variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "project_name" {
  description = "Project name (used in the user-data web page)."
  type        = string
}

variable "environment" {
  description = "Environment name, rendered on the test web page (e.g. production)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "IDs of the private application subnets the ASG deploys instances into."
  type        = list(string)
}

variable "app_sg_id" {
  description = "ID of the application security group to attach to instances."
  type        = string
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile to attach to instances."
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group the ASG should register instances with."
  type        = string
}

variable "db_host" {
  description = "RDS endpoint hostname the application connects to."
  type        = string
}

variable "db_port" {
  description = "Port the RDS instance listens on."
  type        = number
}

variable "db_name" {
  description = "Name of the application database."
  type        = string
}

variable "db_username" {
  description = "Database username used by the application."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password used by the application. Injected into an instance-local env file (root-readable only) - see README security notes."
  type        = string
  sensitive   = true
}

variable "db_engine" {
  description = "Database engine (postgres or mysql) - selects the Python driver the app uses."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances in the ASG."
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG."
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances in the ASG."
  type        = number
}

variable "cpu_target" {
  description = "Target average CPU utilization (%) for the scale-out/scale-in target tracking policy."
  type        = number
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization (%) used only for the informational low-CPU CloudWatch alarm."
  type        = number
  default     = 30
}

variable "root_volume_size" {
  description = "Size (GiB) of the root EBS volume."
  type        = number
  default     = 40
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
