data "azurerm_client_config" "current" {}

# 1. Register the ManagedGPUExperiencePreview feature, Subscription Feature Registration (SFR)
resource "azapi_resource_action" "gpu_feature" {
  type                   = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.ContainerService/subscriptionFeatureRegistrations/ManagedGPUExperiencePreview"
  action                 = ""
  method                 = "PUT"
  response_export_values = ["*"]
}


# 2. Re-register the Resource Provider (RP) so the feature takes effect
resource "azurerm_resource_provider_registration" "mcs" {
  name       = "Microsoft.ContainerService"

  depends_on = [
    azapi_resource_action.gpu_feature
    ]
}