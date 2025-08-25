#----------------------------------------------------------------
# General configuration
#----------------------------------------------------------------
locals {
  name = substr("kv-${var.base_name}-${var.environment}-${var.location}${var.suffix != "" ? "-${var.suffix}" : ""}", 0, 23)
}

resource "azurerm_key_vault" "this" {
  name                            = local.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  sku_name                        = var.sku_name
  tenant_id                       = var.tenant_id
  enable_rbac_authorization       = var.enable_rbac_authorization
  enabled_for_template_deployment = var.enabled_for_template_deployment
  soft_delete_retention_days      = var.soft_delete_retention_days
  purge_protection_enabled        = var.purge_protection_enabled

  network_acls {
    bypass         = var.network_acls_bypass
    default_action = var.network_acls_default_action
    ip_rules       = toset(var.allowed_ips)
  }

  tags = var.tags
}

# The below resource is used to update the Key Vault's IP whitelist.  
# Ideally the above resource should update the firewall to whitelist build agent IP, but it is not working as expected.
# There seems to be a bug in the azurerm_key_vault resource, specifically there seems to be a conflict 
# between the network_acls block and the enable_rbac_authorization property.
resource "azapi_update_resource" "whitelist_build_agent_ip" {
  type        = "Microsoft.KeyVault/vaults@2023-07-01"
  resource_id = azurerm_key_vault.this.id

  body = {
    properties = {
      networkAcls = {
        ipRules = [
          for ip in var.allowed_ips : {
            value = "${ip}/32"
          }
        ]
      }
    }
  }

  depends_on = [azurerm_key_vault.this, module.private_endpoint]
}

module "private_endpoint" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_key_vault.this.id
  resource_name                   = local.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.subresource_names
  private_dns_zone_ids            = var.private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_key_vault.this]
}        