variable "organization_code" {
  description = "Full organization code used in resource naming (e.g. comharte)"
  type        = string
}

variable "resources_location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "environment_groups" {
  description = "Map of environment group names to their constituent environments"
  type        = map(list(string))
  default = {
    nonprod = ["dev", "test"]
    prod    = ["prod"]
  }
}