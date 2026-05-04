variable "organization_code" {
  description = "Full organization code used in resource naming (e.g. comharte)"
  type        = string
}

variable "organization_short_code" {
  description = "Short organization code for length-constrained resources (e.g. cht)"
  type        = string
}

variable "resources_location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}
