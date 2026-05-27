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

variable "environment" {
  description = "Environment name (e.g. dev, test, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name used in resource naming and as the container image name"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy. Required when with_hosting is true."
  type        = string
  default     = ""
}

variable "with_hosting" {
  description = "Whether to deploy the container app hosting resources"
  type        = bool
  default     = true
}

variable "api_service_names" {
  description = "List of apps-service app names whose API permissions this web app requires"
  type        = list(string)
  default     = []
}

variable "ingress_port" {
  description = "Port the container listens on for HTTP traffic"
  type        = number
  default     = 80
}
