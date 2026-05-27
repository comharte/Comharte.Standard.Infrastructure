output "nginx_fqdn" {
  value = azurerm_container_app.nginx.ingress[0].fqdn
}
