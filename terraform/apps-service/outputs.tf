output "app_identity_ids" {
  value = local.app_identity_ids
}

output "sql_server_fqdn" {
  value = data.azurerm_mssql_server.global.fully_qualified_domain_name
}

output "sql_server_name" {
  value = data.azurerm_mssql_server.global.name
}

output "sql_server_resource_group" {
  value = data.azurerm_mssql_server.global.resource_group_name
}

output "database_name" {
  value = azurerm_mssql_database.app.name
}

output "managed_identity_name" {
  value = azurerm_user_assigned_identity.app.name
}

output "service_principal_name" {
  value = azuread_service_principal.app.display_name
}
