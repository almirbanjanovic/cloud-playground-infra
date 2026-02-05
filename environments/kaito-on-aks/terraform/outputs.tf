output "resource_group_name" {
  description = "Name of the resource group"
  value       = var.resource_group_name
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "kube_config_command" {
  description = "Command to get kubeconfig"
  value       = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${azurerm_kubernetes_cluster.this.name}"
}

output "kaito_namespace" {
  description = "Namespace where KAITO workloads are deployed"
  value       = kubernetes_namespace_v1.custom_cpu_inference.metadata[0].name
}

output "kaito_workspace" {
  description = "Name of the KAITO workspace (also the LoadBalancer service name)"
  value       = local.kaito_workspace
}

output "get_external_ip_command" {
  description = "Command to get the external IP of the KAITO LoadBalancer"
  value       = "kubectl get svc ${local.kaito_workspace} -n ${kubernetes_namespace_v1.custom_cpu_inference.metadata[0].name} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}
