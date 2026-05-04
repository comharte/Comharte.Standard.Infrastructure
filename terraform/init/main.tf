data "azurerm_subscription" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

# Resource Provider Registrations
resource "azurerm_resource_provider_registration" "app" {
  name = "Microsoft.App"
}

resource "azurerm_resource_group" "infrastructure" {
  name     = "${var.organization_code}-infrastructure-global"
  location = var.resources_location
}

resource "azurerm_resource_group" "global" {
  for_each = var.environment_groups
  name     = "${var.organization_code}-infrastructure-global-${each.key}"
  location = var.resources_location
}

resource "azurerm_storage_account" "terraform_states" {
  name                     = "${var.organization_code}tfstates"
  resource_group_name      = azurerm_resource_group.infrastructure.name
  location                 = var.resources_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "terraform_states" {
  for_each              = var.environment_groups
  name                  = "terraform-states-${each.key}"
  storage_account_id    = azurerm_storage_account.terraform_states.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "terraform_states_global" {
  name                  = "terraform-states-global"
  storage_account_id    = azurerm_storage_account.terraform_states.id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "devops_deployments" {
  name                = "${var.organization_code}-devops-deployments"
  resource_group_name = azurerm_resource_group.infrastructure.name
  location            = var.resources_location
}

resource "azurerm_role_definition" "subscription_read" {
  name  = "${var.organization_code}-subscription-read"
  scope = data.azurerm_subscription.current.id

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/read",
      "Microsoft.Storage/storageAccounts/read",
    ]
  }
}

resource "azurerm_role_assignment" "devops_deployments_storage_blob_contributor" {
  scope                = azurerm_storage_account.terraform_states.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_subscription_read" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.subscription_read.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_contributor" {
  for_each             = var.environment_groups
  scope                = azurerm_resource_group.global[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azuread_app_role_assignment" "devops_deployments_msgraph_application_readwrite" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.devops_deployments.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_directory_role" "directory_readers" {
  display_name = "Directory Readers"
}

resource "azuread_directory_role_assignment" "devops_deployments_directory_readers" {
  role_id             = azuread_directory_role.directory_readers.object_id
  principal_object_id = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_key_vault_secrets_officer" {
  for_each             = var.environment_groups
  scope                = azurerm_resource_group.global[each.key].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_key_vault_certificates_officer" {
  for_each             = var.environment_groups
  scope                = azurerm_resource_group.global[each.key].id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_infrastructure_contributor" {
  scope                = azurerm_resource_group.infrastructure.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_infrastructure_user_access_administrator" {
  scope                = azurerm_resource_group.infrastructure.id
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_user_access_administrator" {
  for_each             = var.environment_groups
  scope                = azurerm_resource_group.global[each.key].id
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_network_contributor" {
  for_each             = var.environment_groups
  scope                = azurerm_resource_group.global[each.key].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}

resource "azurerm_role_assignment" "devops_deployments_infrastructure_network_contributor" {
  scope                = azurerm_resource_group.infrastructure.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.devops_deployments.principal_id
}
