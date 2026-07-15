variable "resource_group_name" {
  type        = string
  description = "Resource group that owns the target VNet."
}

variable "virtual_network_name" {
  type        = string
  description = "Name of the VNet the subnets will be created in."
}

variable "subnets" {
  description = <<-EOT
    Map of subnets to create. The map KEY is a stable logical identifier used
    for state addressing and output lookups (e.g. "pep", "agent"). Each value
    supplies the actual Azure subnet name and address configuration.

    Example:
      subnets = {
        pep = {
          name             = "snet-pep-dev"
          address_prefixes = ["10.0.1.0/24"]
        }
        agent = {
          name             = "snet-agent-dev"
          address_prefixes = ["10.0.10.0/24"]
          delegations = [{
            name = "Microsoft.App/environments"
            service_delegation = {
              name    = "Microsoft.App/environments"
              actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
            }
          }]
        }
      }
  EOT

  type = map(object({
    name             = string
    address_prefixes = list(string)

    delegations = optional(list(object({
      name = string
      service_delegation = object({
        name    = string
        actions = optional(list(string), [])
      })
    })), [])

    service_endpoints = optional(list(string), [])
  }))
}
