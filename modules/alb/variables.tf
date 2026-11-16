variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets to deploy the ALB into (must span at least 2 AZs)."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ID of the security group to attach to the ALB."
  type        = string
}

variable "health_check_path" {
  description = "Path the Target Group health check requests. The app exposes /health as an app-only liveness check independent of DB status."
  type        = string
  default     = "/health"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
