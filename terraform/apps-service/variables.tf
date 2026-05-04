variable "organization_code" {
  description = "Organization code used solely to locate the environment-group remote state backend"
  type        = string
}

variable "environment_group" {
  description = "Environment group name (e.g. nonprod, prod)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, test, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name used in resource naming and as the container image name"
  type        = string
}
