variable "organization_code" {
  description = "Organization code used solely to locate the global remote state backend"
  type        = string
}

variable "environment_group" {
  description = "Environment group name (e.g. nonprod, prod)"
  type        = string
}

variable "is_production" {
  description = "Whether this environment group is production"
  type        = bool
  default     = false
}

