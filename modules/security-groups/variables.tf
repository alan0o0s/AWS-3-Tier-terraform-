variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to create security groups in."
  type        = string
}

variable "db_port" {
  description = "Port the database engine listens on (5432 for postgres, 3306 for mysql)."
  type        = number
}

variable "enable_ssh" {
  description = "Whether to allow SSH ingress on the application security group."
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into application instances, only used when enable_ssh is true."
  type        = string
  default     = "0.0.0.0/32"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
