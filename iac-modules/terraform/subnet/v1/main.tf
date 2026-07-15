#--------------------------------------------------------------------------------------------------------------------------------
# Subnet module — creates one or more subnets in a caller-provided VNet.
#
# The map key is a stable *logical* identifier used for Terraform state
# addressing and for lookups in outputs (e.g. `module.subnets.subnet_ids["pep"]`).
# The actual Azure subnet name comes from `each.value.name` and can follow any
# naming convention the caller wants.
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints

  dynamic "delegation" {
    for_each = each.value.delegations
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}
