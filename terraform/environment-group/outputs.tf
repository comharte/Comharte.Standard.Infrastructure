output "organization_code" {
  value = local.organization_code
}

output "container_registry_id" {
  value = data.terraform_remote_state.global.outputs.container_registry_id
}

output "container_registry_login_server" {
  value = data.terraform_remote_state.global.outputs.container_registry_login_server
}

output "resource_group_id" {
  value = azurerm_resource_group.environment_group.id
}

output "resource_group_name" {
  value = azurerm_resource_group.environment_group.name
}

output "resource_group_location" {
  value = azurerm_resource_group.environment_group.location
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.environment_group.id
}

output "key_vault_id" {
  value = azurerm_key_vault.environment_group.id
}

output "key_vault_name" {
  value = azurerm_key_vault.environment_group.name
}

output "is_production" {
  value = var.is_production
}

output "certificate_id" {
  value = azurerm_key_vault_certificate.environment_group.id
}

output "certificate_secret_id" {
  value = azurerm_key_vault_certificate.environment_group.secret_id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.environment_group.id
}

output "cae_subnet_id" {
  value = azurerm_subnet.cae.id
}
