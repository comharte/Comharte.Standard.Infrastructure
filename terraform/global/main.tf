data "azurerm_resource_group" "infrastructure" {
  name = "${var.organization_code}-infrastructure-global"
}

# Container Registry
resource "azurerm_container_registry" "global" {
  name                = "${var.organization_code}acr"
  resource_group_name = data.azurerm_resource_group.infrastructure.name
  location            = data.azurerm_resource_group.infrastructure.location
  sku                 = "Basic"
}
