data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group
    storage_account_name = var.backend_storage_account
    container_name       = "terraform-states-global"
    key                  = "global.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "environment_group" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group
    storage_account_name = var.backend_storage_account
    container_name       = "terraform-states-${var.environment_group}"
    key                  = "environment-group.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  organization_code            = data.terraform_remote_state.global.outputs.organization_code
  container_app_environment_id = data.terraform_remote_state.environment_group.outputs.container_app_environment_id
  resource_group_name          = data.terraform_remote_state.environment_group.outputs.resource_group_name
  global_key_vault_id          = data.terraform_remote_state.global.outputs.key_vault_id
}

# Write Nginx FQDN to global Key Vault for consumption by other modules
resource "azurerm_key_vault_secret" "nginx_fqdn" {
  name         = "${var.environment_group}-reverse-proxy"
  value        = azurerm_container_app.nginx.ingress[0].fqdn
  key_vault_id = local.global_key_vault_id
}

# Nginx Container App — routing config injected via secret, maintained externally
resource "azurerm_container_app" "nginx" {
  name                         = "${local.organization_code}-nginx-${var.environment_group}"
  resource_group_name          = local.resource_group_name
  container_app_environment_id = local.container_app_environment_id
  revision_mode                = "Single"

  secret {
    name  = "nginx-config"
    value = var.nginx_config
  }

  ingress {
    external_enabled = false
    target_port      = 80
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "nginx"
      image  = "nginx:alpine"
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/sh", "-c", "cp /mnt/nginx-config/nginx-config /etc/nginx/nginx.conf && nginx -g 'daemon off;'"]

      volume_mount {
        name = "nginx-config-vol"
        path = "/mnt/nginx-config"
      }
    }

    volume {
      name         = "nginx-config-vol"
      storage_type = "Secret"
    }
  }
}
