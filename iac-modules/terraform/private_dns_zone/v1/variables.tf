variable "tags" {
  description = "Tags applied to the private DNS zone and its VNet link."
  type        = map(string)
}

variable "dns_zone" {
  description = "Fully-qualified DNS zone name to create, e.g. `privatelink.blob.core.windows.net` or `privatelink.documents.azure.com`."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that owns the zone."
  type        = string
}

variable "virtual_network_id" {
  description = "ID of the VNet this zone should be linked to (so VMs in that VNet resolve `dns_zone` records to private endpoint IPs)."
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the VNet — used as the zone's link name for readability in the Portal."
  type        = string
}