output "global_resource_group" {
  value = var.global_resource_group
}

output "organization_name" {
  value = var.organization_name
}

output "organization_code" {
  value = var.organization_code
}

output "resources_location" {
  value = var.resources_location
}

output "devops_deployments_identity_id" {
  value = azurerm_user_assigned_identity.devops_deployments.id
}

output "devops_deployments_principal_id" {
  value = azurerm_user_assigned_identity.devops_deployments.principal_id
}

output "devops_deployments_client_id" {
  value = azurerm_user_assigned_identity.devops_deployments.client_id
}

output "container_registry_id" {
  value = azurerm_container_registry.global.id
}

output "container_registry_login_server" {
  value = azurerm_container_registry.global.login_server
}
