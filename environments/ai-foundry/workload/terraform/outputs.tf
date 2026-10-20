#================================================================================
# Effective regions and names of the BYO data services. Use `terraform output`
# to verify a cross-region deployment, or to rebuild terraform.tfvars if it is
# lost (every later plan / apply / destroy must see the same values).
#================================================================================

output "storage_location" {
  description = "Region of the Storage account."
  value       = local.storage_location
}

output "cosmos_location" {
  description = "Region of the Cosmos DB account."
  value       = local.cosmos_location
}

output "ai_search_location" {
  description = "Region of the AI Search service."
  value       = local.ai_search_location
}

output "storage_account_name" {
  description = "Name of the Storage account."
  value       = module.storage.name
}

output "cosmos_account_name" {
  description = "Name of the Cosmos DB account."
  value       = module.cosmos_db.name
}

output "ai_search_name" {
  description = "Name of the AI Search service."
  value       = module.ai_search.name
}
