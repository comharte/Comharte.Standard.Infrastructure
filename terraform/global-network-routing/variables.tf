variable "backend_resource_group" {
  description = "Resource group containing the Terraform state storage account"
  type        = string
}

variable "backend_storage_account" {
  description = "Storage account name for Terraform state"
  type        = string
}

variable "listeners" {
  description = "Map of listener URL to environment group name. https:// URLs create an HTTPS listener and load the certificate from global Key Vault using the hostname-derived name (e.g. https://comharte.com → cert 'comharte-com'). http:// creates an HTTP listener. Each URL is routed to the reverse proxy of the specified environment group (e.g. { \"https://comharte.com\" = \"prod\", \"https://staging.comharte.com\" = \"nonprod\" })."
  type        = map(string)
  default     = {}
}
