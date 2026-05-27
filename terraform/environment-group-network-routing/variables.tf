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

variable "nginx_config" {
  description = "Raw Nginx configuration file content. Injected as a Container App secret and mounted at /etc/nginx/nginx.conf."
  type        = string
  default     = ""
}
