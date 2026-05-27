data "azurerm_client_config" "current" {}

data "terraform_remote_state" "global_admin" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group
    storage_account_name = var.backend_storage_account
    container_name       = "terraform-states-global"
    key                  = "global-admin.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  organization_name     = data.terraform_remote_state.global_admin.outputs.organization_name
  organization_code     = data.terraform_remote_state.global_admin.outputs.organization_code
  location              = data.terraform_remote_state.global_admin.outputs.resources_location
  global_resource_group = data.terraform_remote_state.global_admin.outputs.global_resource_group
}

data "azurerm_resource_group" "global" {
  name = local.global_resource_group
}

# Global VNet
resource "azurerm_virtual_network" "global" {
  name                = "${local.organization_name}-vnet-global"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = local.location
  address_space       = ["10.0.0.0/8"]
}

# AGW subnet
resource "azurerm_subnet" "agw" {
  name                 = "${local.organization_name}-agw-subnet-global"
  resource_group_name  = data.azurerm_resource_group.global.name
  virtual_network_name = azurerm_virtual_network.global.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Global Key Vault
resource "azurerm_key_vault" "global" {
  name                       = "${local.organization_code}-kv-global"
  resource_group_name        = data.azurerm_resource_group.global.name
  location                   = local.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
}

# Static public IP for Application Gateway
resource "azurerm_public_ip" "agw" {
  name                = "${local.organization_name}-pip-global"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = local.location
  allocation_method   = "Static"
  sku                 = "Standard"
}
