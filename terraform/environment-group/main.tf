data "azurerm_client_config" "current" {}

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = {
    resource_group_name  = "${var.organization_code}-infrastructure-global"
    storage_account_name = "${var.organization_code}tfstates"
    container_name       = "terraform-states-global"
    key                  = "global.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  organization_code       = data.terraform_remote_state.global.outputs.organization_code
  organization_short_code = data.terraform_remote_state.global.outputs.organization_short_code
  key_vault_config_prefix = "${var.environment_group}-${local.organization_code}"
}

data "azurerm_resource_group" "global" {
  name = "${local.organization_code}-infrastructure-global-${var.environment_group}"
}

data "azurerm_user_assigned_identity" "devops_deployments" {
  name                = "${local.organization_code}-devops-deployments"
  resource_group_name = "${local.organization_code}-infrastructure-global"
}

# SQL Server
resource "azurerm_mssql_server" "global" {
  name                = "${local.organization_code}-sql-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
  version             = "12.0"

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.devops_deployments.id]
  }

  primary_user_assigned_identity_id = data.azurerm_user_assigned_identity.devops_deployments.id

  azuread_administrator {
    login_username              = data.azurerm_user_assigned_identity.devops_deployments.name
    object_id                   = data.azurerm_user_assigned_identity.devops_deployments.principal_id
    azuread_authentication_only = true
  }
}

# Service Bus
resource "azurerm_servicebus_namespace" "global" {
  name                = "${local.organization_code}-sb-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
  sku                 = "Standard"
}

# Virtual Network
resource "azurerm_virtual_network" "global" {
  name                = "${local.organization_code}-vnet-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
  address_space       = ["10.0.0.0/8"]
}

# CAE subnet — internal load balancer, VNet-integrated
resource "azurerm_subnet" "cae" {
  name                 = "${local.organization_code}-cae-subnet-${var.environment_group}"
  resource_group_name  = data.azurerm_resource_group.global.name
  virtual_network_name = azurerm_virtual_network.global.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "global" {
  name                = "${local.organization_code}-law-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Container Apps Environment
resource "azurerm_container_app_environment" "global" {
  name                           = "${local.organization_code}-cae-${var.environment_group}"
  resource_group_name            = data.azurerm_resource_group.global.name
  location                       = data.azurerm_resource_group.global.location
  infrastructure_subnet_id       = azurerm_subnet.cae.id
  internal_load_balancer_enabled = true
  public_network_access          = "Disabled"
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.global.id
}

# Key Vault
resource "azurerm_key_vault" "global" {
  name                = "${local.organization_short_code}-kv-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
}

# Connection String Builder secrets
resource "azurerm_key_vault_secret" "connection_string_server" {
  name         = "${local.key_vault_config_prefix}--ConnectionStringBuilderConfiguration--Domain--Server"
  value        = azurerm_mssql_server.global.fully_qualified_domain_name
  key_vault_id = azurerm_key_vault.global.id
}

resource "azurerm_key_vault_secret" "servicebus_internal_processing_hostname" {
  name         = "${local.key_vault_config_prefix}--AzureServiceBusConfiguration--Senders--internal-processing--HostName"
  value        = "${azurerm_servicebus_namespace.global.name}.servicebus.windows.net"
  key_vault_id = azurerm_key_vault.global.id
}

resource "azurerm_key_vault_secret" "servicebus_global_events_hostname" {
  name         = "${local.key_vault_config_prefix}--AzureServiceBusConfiguration--Senders--global-events--HostName"
  value        = "${azurerm_servicebus_namespace.global.name}.servicebus.windows.net"
  key_vault_id = azurerm_key_vault.global.id
}

resource "azurerm_key_vault_secret" "servicebus_processors_internal_processing_hostname" {
  name         = "${local.key_vault_config_prefix}--AzureServiceBusConfiguration--Processors--internal-processing--HostName"
  value        = "${azurerm_servicebus_namespace.global.name}.servicebus.windows.net"
  key_vault_id = azurerm_key_vault.global.id
}

resource "azurerm_key_vault_secret" "endpoint_configuration_authentication_bearer_default_authority" {
  name         = "${local.key_vault_config_prefix}--EndpointConfiguration--Authentication--Bearer--Default--Authority"
  value        = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}"
  key_vault_id = azurerm_key_vault.global.id
}

# Self-signed certificate
resource "azurerm_key_vault_certificate" "global" {
  name         = "${local.organization_short_code}-${var.environment_group}-cert"
  key_vault_id = azurerm_key_vault.global.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]
      subject            = "CN=${local.organization_code}"
      validity_in_months = 12
    }
  }
}
