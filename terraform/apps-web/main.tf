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

data "terraform_remote_state" "environment_group" {
  backend = "azurerm"
  config = {
    resource_group_name  = "${var.organization_code}-infrastructure-global"
    storage_account_name = "${var.organization_code}tfstates"
    container_name       = "terraform-states-${var.environment_group}"
    key                  = "${var.environment_group}.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  organization_code               = data.terraform_remote_state.global.outputs.organization_code
  organization_short_code         = data.terraform_remote_state.global.outputs.organization_short_code
  container_registry_login_server = data.terraform_remote_state.global.outputs.container_registry_login_server
  container_registry_id           = data.terraform_remote_state.global.outputs.container_registry_id
  container_app_environment_id    = data.terraform_remote_state.environment_group.outputs.container_app_environment_id
  resource_group_name             = data.terraform_remote_state.environment_group.outputs.resource_group_name
  key_vault_id                    = data.terraform_remote_state.environment_group.outputs.key_vault_id
  app_fully_qualified_name        = "${var.environment}-${local.organization_code}-${var.app_name}-web"
}

data "azurerm_resource_group" "global" {
  name = local.resource_group_name
}

moved {
  from = azurerm_user_assigned_identity.app
  to   = module.hosting[0].azurerm_user_assigned_identity.app
}

moved {
  from = azurerm_role_assignment.app_acr_pull
  to   = module.hosting[0].azurerm_role_assignment.app_acr_pull
}

moved {
  from = azurerm_container_app.web
  to   = module.hosting[0].azurerm_container_app.web
}

moved {
  from = azurerm_role_assignment.app_key_vault_secrets_reader
  to   = module.hosting[0].azurerm_role_assignment.app_key_vault_secrets_reader
}

moved {
  from = azurerm_key_vault_secret.app_url
  to   = module.hosting[0].azurerm_key_vault_secret.app_url
}

module "hosting" {
  count  = var.with_hosting ? 1 : 0
  source = "../apps-web-hosting"

  app_fully_qualified_name        = local.app_fully_qualified_name
  resource_group_name             = local.resource_group_name
  location                        = data.azurerm_resource_group.global.location
  container_registry_login_server = local.container_registry_login_server
  container_registry_id           = local.container_registry_id
  container_app_environment_id    = local.container_app_environment_id
  key_vault_id                    = local.key_vault_id
  app_name                        = var.app_name
  image_tag                       = var.image_tag
  ingress_port                    = var.ingress_port
}

resource "azuread_application" "app" {
  display_name     = local.app_fully_qualified_name
  sign_in_audience = "AzureADMultipleOrgs"
  tags             = ["apps-web"]
}

resource "azuread_application_identifier_uri" "app" {
  application_id = azuread_application.app.id
  identifier_uri = "api://${azuread_application.app.client_id}"
}

resource "azuread_service_principal" "app" {
  client_id = azuread_application.app.client_id
}


data "azurerm_key_vault_secret" "service_client_id" {
  for_each     = toset(var.api_service_names)
  name         = "${var.environment}-${local.organization_code}-${each.value}-service--AppRegistration--ClientId"
  key_vault_id = local.key_vault_id
}

data "azurerm_key_vault_secret" "service_scope_id" {
  for_each     = toset(var.api_service_names)
  name         = "${var.environment}-${local.organization_code}-${each.value}-service--AppRegistration--ScopeId--AccessAsUser"
  key_vault_id = local.key_vault_id
}

resource "azuread_application_api_access" "services" {
  for_each       = toset(var.api_service_names)
  application_id = azuread_application.app.id
  api_client_id  = data.azurerm_key_vault_secret.service_client_id[each.key].value
  scope_ids      = [data.azurerm_key_vault_secret.service_scope_id[each.key].value]
}