#================================================================================
# Outputs from the base stack.
#
# The workload stack reads these via data sources (by name), not
# `terraform_remote_state`, so it stays decoupled from base's state file.
# These outputs still exist for humans / other consumers (e.g. printing the
# jumpbox IP after apply, wiring the runner UAMI's client ID into GitHub
# environment secrets).
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

output "jumpbox_public_ip" {
  description = "Public IP of the jumpbox. Use with `ssh azureuser@<ip>` or `az ssh vm --name <name>`."
  value       = module.jumpbox.public_ip_address
}

output "jumpbox_vm_name" {
  description = "Jumpbox VM name."
  value       = module.jumpbox.vm_name
}

output "runner_uami_client_id" {
  description = "Client ID of the CI/CD runner's user-assigned managed identity. Set this as the `azureClientId` secret in the `ai-foundry-workload` GitHub environment."
  value       = module.cicd_runner.user_assigned_client_id
}

output "runner_uami_principal_id" {
  description = "Principal ID of the CI/CD runner's UAMI."
  value       = module.cicd_runner.user_assigned_principal_id
}

output "runner_vm_name" {
  description = "CI/CD runner VM name."
  value       = module.cicd_runner.vm_name
}
