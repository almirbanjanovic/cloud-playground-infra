output "sfr_state_json" {
  value       = data.azapi_resource.aks_gpu_feature_sfr_read.output
  description = "Look for properties.provisioningState and/or properties.state == 'Registered'"
}