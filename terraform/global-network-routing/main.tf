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

locals {
  organization_code  = data.terraform_remote_state.global.outputs.organization_code
  resource_group_name = data.terraform_remote_state.global.outputs.global_resource_group
  location           = data.terraform_remote_state.global.outputs.resources_location
  agw_subnet_id      = data.terraform_remote_state.global.outputs.agw_subnet_id
  public_ip_id       = data.terraform_remote_state.global.outputs.public_ip_id
  key_vault_id       = data.terraform_remote_state.global.outputs.key_vault_id

  # Sort URLs for stable priority assignment across applies
  sorted_urls = sort(keys(var.listeners))

  # Parse each listener URL into scheme, hostname, environment_group, and a stable key
  listeners_list = [for i, url in local.sorted_urls : {
    url               = url
    environment_group = var.listeners[url]
    scheme            = regex("^(https?)://", url)[0]
    hostname          = regex("^https?://([^/]+)", url)[0]
    key               = replace(regex("^https?://([^/]+)", url)[0], ".", "-")
    priority          = 200 + i * 10
  }]

  listeners_map       = { for l in local.listeners_list : l.key => l }
  listeners_https     = { for k, l in local.listeners_map : k => l if l.scheme == "https" }
  listeners_http_only = { for k, l in local.listeners_map : k => l if l.scheme == "http" }
  cert_names          = toset([for l in local.listeners_list : l.key if l.scheme == "https"])

  # Unique set of environment groups referenced by listeners
  environment_groups = toset(values(var.listeners))
}

# Reverse proxy FQDNs — one per environment group, written by environment-group-network-routing
data "azurerm_key_vault_secret" "reverse_proxy" {
  for_each     = local.environment_groups
  name         = "${each.key}-reverse-proxy"
  key_vault_id = local.key_vault_id
}

# SSL certificates — read from global Key Vault using hostname-derived cert name
data "azurerm_key_vault_secret" "ssl_certificates" {
  for_each     = local.cert_names
  name         = each.key
  key_vault_id = local.key_vault_id
}

# Application Gateway
resource "azurerm_application_gateway" "global" {
  name                = "${local.organization_code}-agw"
  resource_group_name = local.resource_group_name
  location            = local.location

  sku {
    name     = "Basic"
    tier     = "Basic"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = local.agw_subnet_id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = local.public_ip_id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  # SSL certificates — keyed by hostname-derived cert name
  dynamic "ssl_certificate" {
    for_each = local.cert_names
    content {
      name     = ssl_certificate.key
      data     = data.azurerm_key_vault_secret.ssl_certificates[ssl_certificate.key].value
      password = ""
    }
  }

  # One backend pool per environment group, pointing to its reverse proxy
  dynamic "backend_address_pool" {
    for_each = local.environment_groups
    content {
      name  = "${backend_address_pool.key}-pool"
      fqdns = [data.azurerm_key_vault_secret.reverse_proxy[backend_address_pool.key].value]
    }
  }

  # One backend HTTP settings block per environment group
  dynamic "backend_http_settings" {
    for_each = local.environment_groups
    content {
      name                                = "${backend_http_settings.key}-settings"
      cookie_based_affinity               = "Disabled"
      port                                = 80
      protocol                            = "Http"
      request_timeout                     = 30
      pick_host_name_from_backend_address = false
      probe_name                          = "${backend_http_settings.key}-probe"
    }
  }

  # One health probe per environment group
  dynamic "probe" {
    for_each = local.environment_groups
    content {
      name                = "${probe.key}-probe"
      protocol            = "Http"
      path                = "/health"
      host                = data.azurerm_key_vault_secret.reverse_proxy[probe.key].value
      interval            = 30
      timeout             = 30
      unhealthy_threshold = 3
    }
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

  # HTTPS routing rules — each routes to its environment group's backend pool
  dynamic "request_routing_rule" {
    for_each = local.listeners_https
    content {
      name                       = "https-${request_routing_rule.key}-rule"
      rule_type                  = "Basic"
      priority                   = request_routing_rule.value.priority
      http_listener_name         = "https-${request_routing_rule.key}-listener"
      backend_address_pool_name  = "${request_routing_rule.value.environment_group}-pool"
      backend_http_settings_name = "${request_routing_rule.value.environment_group}-settings"
    }
  }

  # HTTP routing rules — each routes to its environment group's backend pool
  dynamic "request_routing_rule" {
    for_each = local.listeners_http_only
    content {
      name                       = "${request_routing_rule.key}-rule"
      rule_type                  = "Basic"
      priority                   = request_routing_rule.value.priority
      http_listener_name         = "${request_routing_rule.key}-listener"
      backend_address_pool_name  = "${request_routing_rule.value.environment_group}-pool"
      backend_http_settings_name = "${request_routing_rule.value.environment_group}-settings"
    }
  }
}
