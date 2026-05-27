variable "backend_resource_group" {
  description = "Resource group containing the Terraform state storage account"
  type        = string
}

variable "backend_storage_account" {
  description = "Storage account name for Terraform state"
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

variable "cae_subnet_cidr" {
  description = "CIDR block for the Container Apps Environment subnet. Must be unique across all environment groups in the shared VNet (e.g. 10.0.1.0/24 for nonprod, 10.0.2.0/24 for prod)."
  type        = string
}
