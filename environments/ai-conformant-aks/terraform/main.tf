data "azurerm_client_config" "current" {}

# Step 1: Register the ManagedGPUExperiencePreview feature, Subscription Feature Registration (SFR)
resource "azapi_resource_action" "managed_gpu_experience_preview_sfr" {
  type                   = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.ContainerService/subscriptionFeatureRegistrations/ManagedGPUExperiencePreview"
  method                 = "PUT"
  body = {}
  response_export_values = ["*"]
}

# Step 2: Register the ManagedGatewayAPIPreview feature
resource "azapi_resource_action" "managed_gateway_api_preview_sfr" {
  type                   = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.ContainerService/subscriptionFeatureRegistrations/ManagedGatewayAPIPreview"
  method                 = "PUT"
  body                   = {}
  response_export_values = ["*"]
}

# Step 3: Wait for feature registration to propagate (using time_sleep as a simple approach)
resource "time_sleep" "wait_for_features" {
  depends_on = [
    azapi_resource_action.managed_gpu_experience_preview_sfr,
    azapi_resource_action.managed_gateway_api_preview_sfr
  ]
  create_duration = "60s"
}