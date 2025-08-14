output "primary_admin_key" {
  description = "The primary admin key of the Cosmos DB account"
  value       = azurerm_search_service.this.primary_key
}

output "first_query_key" {
  description = "The query key of the Cosmos DB account"
  value       = azurerm_search_service.this.query_keys[0].key
}

output "search_service_url" {
  description = "URL of the Search Service."
  value       = "https://${local.name}.search.windows.net"
}