output "application_gateway_id" {
  value = azurerm_application_gateway.global.id
}

output "application_gateway_name" {
  value = azurerm_application_gateway.global.name
}

output "public_ip_id" {
  value = azurerm_public_ip.global.id
}

output "public_ip_address" {
  value = azurerm_public_ip.global.ip_address
}

output "agw_subnet_id" {
  value = azurerm_subnet.agw.id
}

output "nginx_fqdn" {
  value = azurerm_container_app.nginx.ingress[0].fqdn
}
