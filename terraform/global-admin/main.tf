data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "global" {
  name = var.global_resource_group
}

# Managed Identity for DevOps deployments
resource "azurerm_user_assigned_identity" "devops_deployments" {
  name                = "${var.organization_name}-devops-deployments"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
}

# Subscription-level RBAC for devops-deployments
resource "azurerm_role_assignment" "contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "user_access_administrator" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "key_vault_secrets_officer" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "key_vault_certificates_officer" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

# Container Registry
resource "azurerm_container_registry" "global" {
  name                = "${var.organization_name}acr"
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
  sku                 = "Basic"
}
