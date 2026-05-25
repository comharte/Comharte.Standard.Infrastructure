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

data "azurerm_resource_group" "environment_group" {
  name = data.terraform_remote_state.environment_group.outputs.resource_group_name
}

data "azurerm_virtual_network" "global" {
  name                = "${var.organization_code}-vnet-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.environment_group.name
}

locals {
  container_app_environment_id = data.terraform_remote_state.environment_group.outputs.container_app_environment_id
  key_vault_id                 = data.terraform_remote_state.environment_group.outputs.key_vault_id

  # Parse each listener URL into scheme, hostname and a stable key
  listeners_list = [for i, url in var.listeners : {
    url      = url
    scheme   = regex("^(https?)://", url)[0]
    hostname = regex("^https?://([^/]+)", url)[0]
    key      = replace(regex("^https?://([^/]+)", url)[0], ".", "-")
    priority = 200 + i * 10
  }]
  listeners_map = { for l in local.listeners_list : l.key => l }

  listeners_https     = { for k, l in local.listeners_map : k => l if l.scheme == "https" }
  listeners_http_only = { for k, l in local.listeners_map : k => l if l.scheme == "http" }

  # Unique cert names — one per unique HTTPS hostname, derived as comharte.com → comharte-com
  cert_names = toset([for l in local.listeners_list : l.key if l.scheme == "https"])
}

# SSL certificates — read from environment-group Key Vault using hostname-derived cert name
data "azurerm_key_vault_secret" "ssl_certificates" {
  for_each     = local.cert_names
  name         = each.key
  key_vault_id = local.key_vault_id
}

# AGW subnet
resource "azurerm_subnet" "agw" {
  name                 = "${var.organization_code}-agw-subnet-${var.environment_group}"
  resource_group_name  = data.azurerm_resource_group.environment_group.name
  virtual_network_name = data.azurerm_virtual_network.global.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Static public IP
resource "azurerm_public_ip" "global" {
  name                = "${var.organization_code}-pip-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.environment_group.name
  location            = data.azurerm_resource_group.environment_group.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Nginx Container App — routing config injected via secret, maintained externally
resource "azurerm_container_app" "nginx" {
  name                         = "${var.organization_code}-nginx-${var.environment_group}"
  resource_group_name          = data.azurerm_resource_group.environment_group.name
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

# Application Gateway
resource "azurerm_application_gateway" "global" {
  name                = "${var.organization_code}-agw-${var.environment_group}"
  resource_group_name = data.azurerm_resource_group.environment_group.name
  location            = data.azurerm_resource_group.environment_group.location

  sku {
    name     = "Basic"
    tier     = "Basic"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.agw.id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.global.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  # SSL certificates — loaded from Key Vault, keyed by hostname-derived cert name
  dynamic "ssl_certificate" {
    for_each = local.cert_names
    content {
      name     = ssl_certificate.key
      data     = data.azurerm_key_vault_secret.ssl_certificates[ssl_certificate.key].value
      password = ""
    }
  }

  # Single backend pool pointing to Nginx
  backend_address_pool {
    name  = "nginx-pool"
    fqdns = [azurerm_container_app.nginx.ingress[0].fqdn]
  }

  # HTTP to Nginx — Host header preserved for Nginx server_name routing
  backend_http_settings {
    name                                = "nginx-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 30
    pick_host_name_from_backend_address = false
    probe_name                          = "nginx-probe"
  }

  # Health probe targeting Nginx default_server /health
  probe {
    name                = "nginx-probe"
    protocol            = "Http"
    path                = "/health"
    host                = azurerm_container_app.nginx.ingress[0].fqdn
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }

  # HTTPS listeners
  dynamic "http_listener" {
    for_each = local.listeners_https
    content {
      name                           = "https-${http_listener.key}-listener"
      frontend_ip_configuration_name = "frontend-ip-config"
      frontend_port_name             = "port-443"
      protocol                       = "Https"
      host_name                      = http_listener.value.hostname
      ssl_certificate_name           = http_listener.key
    }
  }

  # HTTP listeners
  dynamic "http_listener" {
    for_each = local.listeners_http_only
    content {
      name                           = "${http_listener.key}-listener"
      frontend_ip_configuration_name = "frontend-ip-config"
      frontend_port_name             = "port-80"
      protocol                       = "Http"
      host_name                      = http_listener.value.hostname
    }
  }

  # HTTPS routing rules
  dynamic "request_routing_rule" {
    for_each = local.listeners_https
    content {
      name                       = "https-${request_routing_rule.key}-rule"
      rule_type                  = "Basic"
      priority                   = request_routing_rule.value.priority
      http_listener_name         = "https-${request_routing_rule.key}-listener"
      backend_address_pool_name  = "nginx-pool"
      backend_http_settings_name = "nginx-settings"
    }
  }

  # HTTP routing rules
  dynamic "request_routing_rule" {
    for_each = local.listeners_http_only
    content {
      name                       = "${request_routing_rule.key}-rule"
      rule_type                  = "Basic"
      priority                   = request_routing_rule.value.priority
      http_listener_name         = "${request_routing_rule.key}-listener"
      backend_address_pool_name  = "nginx-pool"
      backend_http_settings_name = "nginx-settings"
    }
  }

  depends_on = [azurerm_container_app.nginx]
}
