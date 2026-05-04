variable "app_fully_qualified_name" {
  description = "Fully qualified application name used as the key vault secret name prefix"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the key vault to write configuration secrets to"
  type        = string
}
