data "azurerm_resource_group" "infrastructure" {
  name = "${var.organization_code}-infrastructure-global"
}

locals {
  # Stable key derived from public_url, e.g. "dev-home-comharte-com"
  apps_list = [for i, app in var.apps : merge(app, {
    key      = replace(app.public_url, ".", "-")
    priority = 200 + i * 10
  })]
  apps_map = { for app in local.apps_list : app.key => app }

  # Flatten all routing entries: one entry per (app, path) pair
  routings_flat = flatten([
    for app in local.apps_list : [
      for path, fqdn in app.routings : {
        app_key    = app.key
        path       = path
        fqdn       = fqdn
        is_default = path == "*"
        entry_key  = "${app.key}--${path == "*" ? "default" : replace(path, "/", "-")}"
      }
    ]
  ])
  routings_map = { for r in local.routings_flat : r.entry_key => r }

  # Non-default path rules per app
  path_rules = {
    for app in local.apps_list : app.key => {
      for path, fqdn in app.routings : path => fqdn if path != "*"
    }
  }

  # Apps split by whether they have specific path rules
  apps_with_paths = { for k, app in local.apps_map : k => app if length(local.path_rules[k]) > 0 }
  apps_basic      = { for k, app in local.apps_map : k => app if length(local.path_rules[k]) == 0 }

  # Apps split by HTTPS vs HTTP-only
  apps_https     = { for k, app in local.apps_map : k => app if app.ssl_certificate_name != null }
  apps_http_only = { for k, app in local.apps_map : k => app if app.ssl_certificate_name == null }

  # Cross-product splits for routing rule generation
  apps_with_paths_https     = { for k, app in local.apps_with_paths : k => app if app.ssl_certificate_name != null }
  apps_with_paths_http_only = { for k, app in local.apps_with_paths : k => app if app.ssl_certificate_name == null }
  apps_basic_https          = { for k, app in local.apps_basic : k => app if app.ssl_certificate_name != null }
  apps_basic_http_only      = { for k, app in local.apps_basic : k => app if app.ssl_certificate_name == null }
}

resource "azurerm_public_ip" "global" {
  name                = "${var.organization_code}-pip"
  resource_group_name = data.azurerm_resource_group.infrastructure.name
  location            = data.azurerm_resource_group.infrastructure.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network" "global" {
  name                = "${var.organization_code}-vnet"
  resource_group_name = data.azurerm_resource_group.infrastructure.name
  location            = data.azurerm_resource_group.infrastructure.location
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "app_gateway" {
  name                 = "${var.organization_code}-agw-subnet"
  resource_group_name  = data.azurerm_resource_group.infrastructure.name
  virtual_network_name = azurerm_virtual_network.global.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Application Gateway
resource "azurerm_application_gateway" "global" {
  name                = "${var.organization_code}-agw"
  resource_group_name = data.azurerm_resource_group.infrastructure.name
  location            = data.azurerm_resource_group.infrastructure.location

  sku {
    name     = "Basic"
    tier     = "Basic"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
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

  # SSL certificates — one per cert, data injected at deploy time by the pipeline
  dynamic "ssl_certificate" {
    for_each = var.ssl_certificates
    content {
      name     = ssl_certificate.key
      data     = ssl_certificate.value.data
      password = ssl_certificate.value.password
    }
  }

  # One backend pool per routing entry (app + path)
  dynamic "backend_address_pool" {
    for_each = local.routings_map
    content {
      name  = "${backend_address_pool.key}-pool"
      fqdns = [backend_address_pool.value.fqdn]
    }
  }

  # One http settings per routing entry
  dynamic "backend_http_settings" {
    for_each = local.routings_map
    content {
      name                                = "${backend_http_settings.key}-settings"
      cookie_based_affinity               = "Disabled"
      port                                = 443
      protocol                            = "Https"
      request_timeout                     = 30
      pick_host_name_from_backend_address = true
    }
  }

  # HTTP listeners — HTTP-only apps only (HTTPS apps have no HTTP listener)
  dynamic "http_listener" {
    for_each = local.apps_http_only
    content {
      name                           = "${http_listener.key}-listener"
      frontend_ip_configuration_name = "frontend-ip-config"
      frontend_port_name             = "port-80"
      protocol                       = "Http"
      host_name                      = http_listener.value.public_url
    }
  }

  # HTTPS listeners — one per HTTPS-enabled app
  dynamic "http_listener" {
    for_each = local.apps_https
    content {
      name                           = "https-${http_listener.key}-listener"
      frontend_ip_configuration_name = "frontend-ip-config"
      frontend_port_name             = "port-443"
      protocol                       = "Https"
      host_name                      = http_listener.value.public_url
      ssl_certificate_name           = http_listener.value.ssl_certificate_name
    }
  }

  # url_path_maps for HTTPS apps with specific path rules
  dynamic "url_path_map" {
    for_each = local.apps_with_paths_https
    content {
      name                               = "https-${url_path_map.key}-path-map"
      default_backend_address_pool_name  = "${url_path_map.key}--default-pool"
      default_backend_http_settings_name = "${url_path_map.key}--default-settings"

      dynamic "path_rule" {
        for_each = local.path_rules[url_path_map.key]
        content {
          name                       = "${url_path_map.key}--${replace(path_rule.key, "/", "-")}-rule"
          paths                      = ["/${path_rule.key}*"]
          backend_address_pool_name  = "${url_path_map.key}--${replace(path_rule.key, "/", "-")}-pool"
          backend_http_settings_name = "${url_path_map.key}--${replace(path_rule.key, "/", "-")}-settings"
        }
      }
    }
  }

  # url_path_maps for HTTP-only apps with specific path rules
  dynamic "url_path_map" {
    for_each = local.apps_with_paths_http_only
    content {
      name                               = "${url_path_map.key}-path-map"
      default_backend_address_pool_name  = "${url_path_map.key}--default-pool"
      default_backend_http_settings_name = "${url_path_map.key}--default-settings"

      dynamic "path_rule" {
        for_each = local.path_rules[url_path_map.key]
        content {
          name                       = "${url_path_map.key}--${replace(path_rule.key, "/", "-")}-rule"
          paths                      = ["/${path_rule.key}*"]
          backend_address_pool_name  = "${url_path_map.key}--${replace(path_rule.key, "/", "-")}-pool"
          backend_http_settings_name = "${url_path_map.key}--${replace(path_rule.key, "/", "-")}-settings"
        }
      }
    }
  }

  # HTTPS backend routing for HTTPS apps with path rules
  dynamic "request_routing_rule" {
    for_each = local.apps_with_paths_https
    content {
      name               = "https-${request_routing_rule.key}-rule"
      rule_type          = "PathBasedRouting"
      priority           = request_routing_rule.value.priority
      http_listener_name = "https-${request_routing_rule.key}-listener"
      url_path_map_name  = "https-${request_routing_rule.key}-path-map"
    }
  }

  # HTTPS backend routing for HTTPS apps (basic)
  dynamic "request_routing_rule" {
    for_each = local.apps_basic_https
    content {
      name                       = "https-${request_routing_rule.key}-rule"
      rule_type                  = "Basic"
      priority                   = request_routing_rule.value.priority
      http_listener_name         = "https-${request_routing_rule.key}-listener"
      backend_address_pool_name  = "${request_routing_rule.key}--default-pool"
      backend_http_settings_name = "${request_routing_rule.key}--default-settings"
    }
  }

  # HTTP backend routing for HTTP-only apps with path rules
  dynamic "request_routing_rule" {
    for_each = local.apps_with_paths_http_only
    content {
      name               = "${request_routing_rule.key}-rule"
      rule_type          = "PathBasedRouting"
      priority           = request_routing_rule.value.priority
      http_listener_name = "${request_routing_rule.key}-listener"
      url_path_map_name  = "${request_routing_rule.key}-path-map"
    }
  }

  # HTTP backend routing for HTTP-only apps (basic)
  dynamic "request_routing_rule" {
    for_each = local.apps_basic_http_only
    content {
      name                       = "${request_routing_rule.key}-rule"
      rule_type                  = "Basic"
      priority                   = request_routing_rule.value.priority
      http_listener_name         = "${request_routing_rule.key}-listener"
      backend_address_pool_name  = "${request_routing_rule.key}--default-pool"
      backend_http_settings_name = "${request_routing_rule.key}--default-settings"
    }
  }
}
