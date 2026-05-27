output "global_resource_group" {
  value = local.global_resource_group
}

output "organization_name" {
  value = local.organization_name
}

output "organization_code" {
  value = local.organization_code
}

output "resources_location" {
  value = local.location
}

output "devops_deployments_identity_id" {
  value = data.terraform_remote_state.global_admin.outputs.devops_deployments_identity_id
}

output "devops_deployments_principal_id" {
  value = data.terraform_remote_state.global_admin.outputs.devops_deployments_principal_id
}

output "devops_deployments_client_id" {
  value = data.terraform_remote_state.global_admin.outputs.devops_deployments_client_id
}

output "container_registry_id" {
  value = data.terraform_remote_state.global_admin.outputs.container_registry_id
}

output "container_registry_login_server" {
  value = data.terraform_remote_state.global_admin.outputs.container_registry_login_server
}

output "vnet_id" {
  value = azurerm_virtual_network.global.id
}

output "vnet_name" {
  value = azurerm_virtual_network.global.name
}

output "agw_subnet_id" {
  value = azurerm_subnet.agw.id
}

output "public_ip_id" {
  value = azurerm_public_ip.agw.id
}

output "public_ip_address" {
  value = azurerm_public_ip.agw.ip_address
}

output "key_vault_id" {
  value = azurerm_key_vault.global.id
}

output "key_vault_name" {
  value = azurerm_key_vault.global.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.global.vault_uri
}
