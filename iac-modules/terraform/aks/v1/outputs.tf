output "name" {
  description = "The name of the Azure Kubernetes Service cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "id" {
  description = "The ID of the Azure Kubernetes Service cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "host" {
  description = "The Kubernetes cluster host."
  value       = azurerm_kubernetes_cluster.this.kube_admin_config[0].host
}

output "client_certificate" {
  description = "The Kubernetes cluster client certificate."
  value       = azurerm_kubernetes_cluster.this.kube_admin_config[0].client_certificate
}

output "client_key" {
  description = "The Kubernetes cluster client key."
  value       = azurerm_kubernetes_cluster.this.kube_admin_config[0].client_key
}

output "cluster_ca_certificate" {
  description = "The Kubernetes cluster CA certificate."
  value       = azurerm_kubernetes_cluster.this.kube_admin_config[0].cluster_ca_certificate
}