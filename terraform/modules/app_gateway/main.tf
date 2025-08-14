locals {
  name = "agw-${var.base_name}-${var.environment}-${var.location}"

  backend_address_pool_name      = "${local.name}-beap"
  frontend_port_name             = "${local.name}-feport"
  frontend_ip_configuration_name = "${local.name}-feip"
  http_setting_name              = "${local.name}-be-htst"
  listener_name                  = "${local.name}-httplstn"
  request_routing_rule_name      = "${local.name}-rqrt"
  redirect_configuration_name    = "${local.name}-rdrcfg"


  pip_name         = "pip-${local.name}"
  pip_domain_label = "${var.base_name}-${var.environment}"
  waf_policy_name  = "waf-${local.name}"
}

resource "azurerm_public_ip" "this" {
  name                = local.pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.pip_allocation_method
  sku                 = var.pip_sku
  domain_name_label   = local.pip_domain_label

  zones = ["1", "2", "3"]

  tags = var.tags
}

resource "azurerm_web_application_firewall_policy" "this" {
  name                = local.waf_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location

  policy_settings {
    enabled = var.waf_policy_enabled
    mode    = var.waf_policy_mode
  }

  managed_rules {
    managed_rule_set {
      type    = var.managed_rules_rule_set_type
      version = var.managed_rules_rule_set_version
    }
  }

  tags = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  zones               = ["1", "2", "3"]
  firewall_policy_id  = azurerm_web_application_firewall_policy.this.id


  sku {
    name = var.sku_name
    tier = var.sku_tier
  }

  gateway_ip_configuration {
    name      = "ipconfig-${local.name}"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.this.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 1
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      frontend_ip_configuration,
      frontend_port,
      autoscale_configuration,
      tags,
      probe,
      redirect_configuration,
      ssl_certificate,
      url_path_map
    ]
  }
}