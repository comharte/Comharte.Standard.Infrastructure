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

output "virtual_network_id" {
  value = azurerm_virtual_network.global.id
}

output "app_gateway_subnet_id" {
  value = azurerm_subnet.app_gateway.id
}
