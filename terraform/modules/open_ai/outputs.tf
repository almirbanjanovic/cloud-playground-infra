# Openai api key for openai services
output "openai_api_key" {
  value = azurerm_cognitive_account.this.primary_access_key
}
