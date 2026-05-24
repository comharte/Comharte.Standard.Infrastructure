output "organization_code" {
  value = local.organization_code
}

output "organization_short_code" {
  value = local.organization_short_code
}

output "resource_group_name" {
  value = data.azurerm_resource_group.global.name
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.global.id
}

output "key_vault_id" {
  value = azurerm_key_vault.global.id
}

output "is_production" {
  value = var.is_production
}

output "certificate_id" {
  value = azurerm_key_vault_certificate.global.id
}

output "certificate_secret_id" {
  value = azurerm_key_vault_certificate.global.secret_id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.global.id
}

output "vnet_id" {
  value = azurerm_virtual_network.global.id
}

output "cae_subnet_id" {
  value = azurerm_subnet.cae.id
}
