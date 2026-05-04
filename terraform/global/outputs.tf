output "organization_code" {
  value = var.organization_code
}

output "organization_short_code" {
  value = var.organization_short_code
}

output "resources_location" {
  value = var.resources_location
}

output "container_registry_id" {
  value = azurerm_container_registry.global.id
}

output "container_registry_login_server" {
  value = azurerm_container_registry.global.login_server
}
