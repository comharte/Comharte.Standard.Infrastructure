variable "organization_name" {
  description = "Full organization name used in resource naming (e.g. comharte)"
  type        = string
}

variable "organization_code" {
  description = "Short organization code for length-constrained resources (e.g. cht)"
  type        = string
}

variable "global_resource_group" {
  description = "Name of the global infrastructure resource group"
  type        = string
  default     = "infrastructure-global"
}

variable "resources_location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}
