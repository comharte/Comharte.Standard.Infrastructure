output "url" {
  value = "https://${azurerm_container_app.web.ingress[0].fqdn}"
}

output "identity_principal_id" {
  value = azurerm_user_assigned_identity.app.principal_id
}
