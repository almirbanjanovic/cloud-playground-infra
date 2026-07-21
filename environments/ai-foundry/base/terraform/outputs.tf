#================================================================================
# Outputs from the base stack.
#
# The workload stack reads these via data sources (by name), not
# `terraform_remote_state`, so it stays decoupled from base's state file.
# These outputs exist for humans (`terraform output` after base apply).
#================================================================================

output "vnet_id" {
  description = "Resource ID of the shared VNet."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the shared VNet (workload uses this in `data \"azurerm_virtual_network\"`)."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of logical subnet key -> subnet ID."
  value       = module.subnets.subnet_ids
}

output "subnet_names" {
  description = "Map of logical subnet key -> Azure subnet name (workload uses these to `data.azurerm_subnet` by name)."
  value       = module.subnets.subnet_names
}

# -----------------------------------------------------------------------------
# tfstate storage account (consumed as `azurerm` backend by the workload stack)
# -----------------------------------------------------------------------------

output "tfstate_storage_account_name" {
  description = "Name of the Terraform-state storage account. Pass to the workloads terraform init -backend-config=storage_account_name=<value>."
  value       = module.tfstate_storage.name
}

output "tfstate_container_name" {
  description = "Blob container inside the tfstate storage account (default tfstate)."
  value       = azurerm_storage_container.tfstate.name
}

output "tfstate_resource_group_name" {
  description = "Resource group the tfstate storage account lives in (same as bases RG)."
  value       = var.resource_group_name
}