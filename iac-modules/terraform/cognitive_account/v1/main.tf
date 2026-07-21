#--------------------------------------------------------------------------------------------------------------------------------
# General Configuration
#
# `local.name` is a legacy identifier retained for backward compatibility;
# `local.account_name` is the actual Cognitive Services / Foundry account name.
#--------------------------------------------------------------------------------------------------------------------------------
locals {
  name         = "oai-${var.base_name}-${var.environment}-${var.location}"
  account_name = "ais-${var.base_name}-${var.environment}-${var.location}"
}

#--------------------------------------------------------------------------------------------------------------------------------
# Cognitive Services account. `kind` is caller-selected — the ai-foundry
# stack uses `AIServices` (Foundry); OpenAI, generic CognitiveServices, and
# other Cognitive kinds are also supported by the same resource.
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_cognitive_account" "this" {
  name                = local.account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = var.kind
  sku_name            = var.sku_name

  custom_subdomain_name = var.custom_subdomain_name

  project_management_enabled = var.project_management_enabled

  local_auth_enabled            = var.local_auth_enabled
  public_network_access_enabled = var.public_network_access_enabled

  identity {
    type = var.identity_type
  }

  network_acls {
    default_action = var.network_acls_default_action
    bypass         = var.network_acls_bypass
    ip_rules       = var.network_acls_ip_rules
  }

  # Optional Foundry Agent Service network injection. When agent_subnet_id
  # is set, agent-runtime compute is placed inside the caller's VNet
  # instead of the shared Microsoft-managed network. Required for the
  # Standard-Agent-Setup-with-private-networking flavor.
  dynamic "network_injection" {
    for_each = var.agent_subnet_id == null ? [] : [var.agent_subnet_id]
    content {
      scenario  = "agent"
      subnet_id = network_injection.value
    }
  }

  tags = var.tags
}

#--------------------------------------------------------------------------------------------------------------------------------
# Role Assignments (managed identity access)
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = azurerm_cognitive_account.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}

module "open_ai_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_cognitive_account.this.id
  resource_name                   = local.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.subresource_names
  private_dns_zone_ids            = var.private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags
}