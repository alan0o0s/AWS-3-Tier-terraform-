variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy subnets into."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, matched by index to availability_zones."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets, matched by index to availability_zones."
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets, matched by index to availability_zones."
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
