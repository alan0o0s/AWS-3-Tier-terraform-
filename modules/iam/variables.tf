variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
