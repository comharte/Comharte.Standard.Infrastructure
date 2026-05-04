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
  is_production                   = data.terraform_remote_state.environment_group.outputs.is_production
  key_vault_id                    = data.terraform_remote_state.environment_group.outputs.key_vault_id
  log_analytics_workspace_id      = data.terraform_remote_state.environment_group.outputs.log_analytics_workspace_id
  app_fully_qualified_name        = "${var.environment}-${local.organization_code}-${var.app_name}-service"
  app_identity_ids = merge(
    { "managed-identity" = azurerm_user_assigned_identity.app.principal_id },
    local.is_production ? {} : { "service-principal" = azuread_service_principal.app.object_id }
  )
}

data "azurerm_key_vault_certificate_data" "app" {
  count        = local.is_production ? 0 : 1
  name         = "${local.organization_short_code}-${var.environment_group}-cert"
  key_vault_id = local.key_vault_id
}

data "azurerm_resource_group" "global" {
  name = local.resource_group_name
}

data "azurerm_mssql_server" "global" {
  name                = "${local.organization_code}-sql-${var.environment_group}"
  resource_group_name = local.resource_group_name
}

data "azurerm_servicebus_namespace" "global" {
  name                = "${local.organization_code}-sb-${var.environment_group}"
  resource_group_name = local.resource_group_name
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "${local.app_fully_qualified_name}-identity"
  resource_group_name = local.resource_group_name
  location            = data.azurerm_resource_group.global.location
}

resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = local.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "random_uuid" "app_role_read_all" {}
resource "random_uuid" "app_role_write_all" {}
resource "random_uuid" "app_role_basic" {}
resource "random_uuid" "app_role_trusted_service" {}
resource "random_uuid" "app_scope_default" {}

resource "azuread_application" "app" {
  display_name     = local.app_fully_qualified_name
  sign_in_audience = "AzureADMultipleOrgs"
  tags             = ["apps-service"]

  app_role {
    id                   = random_uuid.app_role_read_all.result
    allowed_member_types = ["User"]
    display_name         = "Read.All"
    value                = "Read.All"
    description          = "Read all resources"
    enabled              = true
  }

  app_role {
    id                   = random_uuid.app_role_write_all.result
    allowed_member_types = ["User"]
    display_name         = "Write.All"
    value                = "Write.All"
    description          = "Write all resources"
    enabled              = true
  }

  app_role {
    id                   = random_uuid.app_role_basic.result
    allowed_member_types = ["User"]
    display_name         = "Basic"
    value                = "Basic"
    description          = "Basic access"
    enabled              = true
  }

  app_role {
    id                   = random_uuid.app_role_trusted_service.result
    allowed_member_types = ["Application"]
    display_name         = "TrustedService"
    value                = "TrustedService"
    description          = "Trusted service access"
    enabled              = true
  }

  api {
    oauth2_permission_scope {
      id                         = random_uuid.app_scope_default.result
      admin_consent_description  = "Allow the application to access ${local.app_fully_qualified_name} on behalf of the signed-in user."
      admin_consent_display_name = "Access ${local.app_fully_qualified_name}"
      user_consent_description   = "Allow the application to access ${local.app_fully_qualified_name} on your behalf."
      user_consent_display_name  = "Access ${local.app_fully_qualified_name}"
      value                      = "access_as_user"
      type                       = "User"
      enabled                    = true
    }
  }
}

resource "azuread_application_identifier_uri" "app" {
  application_id = azuread_application.app.id
  identifier_uri = "api://${azuread_application.app.client_id}"
}

resource "azuread_service_principal" "app" {
  client_id = azuread_application.app.client_id
}

resource "azuread_app_role_assignment" "app_trusted_service_self" {
  app_role_id         = random_uuid.app_role_trusted_service.result
  principal_object_id = azuread_service_principal.app.object_id
  resource_object_id  = azuread_service_principal.app.object_id
}

resource "azurerm_application_insights" "app" {
  name                = local.app_fully_qualified_name
  resource_group_name = local.resource_group_name
  location            = data.azurerm_resource_group.global.location
  workspace_id        = local.log_analytics_workspace_id
  application_type    = "web"
}

resource "azurerm_mssql_database" "app" {
  name      = local.app_fully_qualified_name
  server_id = data.azurerm_mssql_server.global.id
  sku_name  = "Basic"
}

resource "azurerm_role_assignment" "app_servicebus_writer" {
  for_each             = local.app_identity_ids
  scope                = data.azurerm_servicebus_namespace.global.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "app_servicebus_reader" {
  for_each             = local.app_identity_ids
  scope                = data.azurerm_resource_group.global.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = each.value
}

resource "azurerm_servicebus_topic" "global_events" {
  name         = "${local.app_fully_qualified_name}-global-events"
  namespace_id = data.azurerm_servicebus_namespace.global.id
}

resource "azurerm_servicebus_topic" "internal_processing" {
  name         = "${local.app_fully_qualified_name}-internal-processing"
  namespace_id = data.azurerm_servicebus_namespace.global.id
}

resource "azurerm_servicebus_subscription" "internal_processing" {
  name               = local.app_fully_qualified_name
  topic_id           = azurerm_servicebus_topic.internal_processing.id
  max_delivery_count = 10
}

resource "azurerm_key_vault_secret" "logger_application_insights_instrumentation_key" {
  name         = "${local.app_fully_qualified_name}--LoggerConfiguration--Sinks--ApplicationInsights--InstrumentationKey"
  value        = azurerm_application_insights.app.instrumentation_key
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "servicebus_global_events_entity_path" {
  name         = "${local.app_fully_qualified_name}--AzureServiceBusConfiguration--Senders--global-events--EntityPath"
  value        = azurerm_servicebus_topic.global_events.name
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "servicebus_internal_processing_entity_path" {
  name         = "${local.app_fully_qualified_name}--AzureServiceBusConfiguration--Senders--internal-processing--EntityPath"
  value        = azurerm_servicebus_topic.internal_processing.name
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "servicebus_processors_internal_processing_entity_path" {
  name         = "${local.app_fully_qualified_name}--AzureServiceBusConfiguration--Processors--internal-processing--EntityPath"
  value        = azurerm_servicebus_topic.internal_processing.name
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "servicebus_processors_internal_processing_subscription_name" {
  name         = "${local.app_fully_qualified_name}--AzureServiceBusConfiguration--Processors--internal-processing--SubscriptionName"
  value        = azurerm_servicebus_subscription.internal_processing.name
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "connection_string_database" {
  name         = "${local.app_fully_qualified_name}--ConnectionStringBuilderConfiguration--Domain--Database"
  value        = azurerm_mssql_database.app.name
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "app_registration_client_id" {
  name         = "${local.app_fully_qualified_name}--AppRegistration--ClientId"
  value        = azuread_application.app.client_id
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "app_registration_scope_id_access_as_user" {
  name         = "${local.app_fully_qualified_name}--AppRegistration--ScopeId--AccessAsUser"
  value        = random_uuid.app_scope_default.result
  key_vault_id = local.key_vault_id
}

resource "azurerm_key_vault_secret" "app_registration_audience" {
  name         = "${local.app_fully_qualified_name}--EndpointConfiguration--Authentication--Bearer--Default--Audience"
  value        = azuread_application.app.client_id
  key_vault_id = local.key_vault_id
}

resource "azurerm_role_assignment" "app_key_vault_secrets_reader" {
  for_each             = local.app_identity_ids
  scope                = local.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

module "configuration_defaults" {
  source = "../apps-service-configuration-defaults"

  app_fully_qualified_name = local.app_fully_qualified_name
  key_vault_id             = local.key_vault_id
}

resource "azuread_application_certificate" "app" {
  count          = local.is_production ? 0 : 1
  application_id = azuread_application.app.id
  type           = "AsymmetricX509Cert"
  value          = data.azurerm_key_vault_certificate_data.app[0].pem
}

