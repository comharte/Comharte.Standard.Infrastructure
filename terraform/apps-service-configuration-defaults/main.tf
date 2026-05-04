resource "azurerm_key_vault_secret" "logger_minimum_level_global" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--MinimumLevel--Global"
  value        = "Verbose"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_sinks_application_insights_enabled" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--Sinks--ApplicationInsights--Enabled"
  value        = "true"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_sinks_application_insights_minimum_level" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--Sinks--ApplicationInsights--MinimumLevel"
  value        = "Verbose"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_minimum_level_override_microsoft" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--MinimumLevel--Override--Microsoft"
  value        = "Warning"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_minimum_level_override_microsoft_aspnetcore" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--MinimumLevel--Override--Microsoft-AspNetCore"
  value        = "Warning"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_minimum_level_override_system" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--MinimumLevel--Override--System"
  value        = "Warning"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_enrich_properties_application" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--Enrich--Properties--Application"
  value        = var.app_fully_qualified_name
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_sinks_console_enabled" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--Sinks--Console--Enabled"
  value        = "true"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "logger_sinks_console_minimum_level" {
  name         = "${var.app_fully_qualified_name}--LoggerConfiguration--Sinks--Console--MinimumLevel"
  value        = "Verbose"
  key_vault_id = var.key_vault_id
}
