// ============================================================================
// Private DNS zone with VNet link — v1
//
// Creates a private DNS zone and links it to the supplied VNet so private
// endpoints auto-register their A records in it (registration is disabled
// by default; enable via `registrationEnabled` for spoke VNets that host PEs).
// ============================================================================

@description('Fully-qualified private DNS zone name (e.g. `privatelink.cognitiveservices.azure.com`).')
param zoneName string

@description('Resource ID of the VNet to link the zone to.')
param vnetId string

@description('Optional VNet link name. Defaults to `<zoneName>-link`.')
param linkName string = ''

@description('Whether the VNet link registers auto-generated A records for VMs in the linked VNet. PE-based zones do NOT need this (PEs create their own A records) so it defaults to false.')
param registrationEnabled bool = false

@description('Tags applied to the zone and link.')
param tags object = {}

resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: zoneName
  location: 'global'
  tags: tags
}

resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: zone
  name: empty(linkName) ? '${zoneName}-link' : linkName
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: registrationEnabled
  }
}

output id string = zone.id
output name string = zone.name
