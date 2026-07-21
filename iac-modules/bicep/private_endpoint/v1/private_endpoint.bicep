// ============================================================================
// Private endpoint + private-DNS-zone-group — v1
//
// Wraps a Microsoft.Network/privateEndpoints resource plus the associated
// privateDnsZoneGroup so the PE's IP auto-registers as an A record in the
// supplied zones. Meant to be called per PE (one for each subresource that
// the target resource exposes).
// ============================================================================

@description('Private endpoint name.')
param name string

@description('Azure location.')
param location string = resourceGroup().location

@description('Resource ID of the target service (e.g. storage account, cosmos, cognitive account).')
param targetResourceId string

@description('List of subresource / groupId names to connect (e.g. ["blob"], ["account"], ["Sql"]).')
param subresourceNames array

@description('Resource ID of the subnet where the PE NIC lives.')
param subnetId string

@description('List of private DNS zone resource IDs that the PE registers its A record(s) in.')
param privateDnsZoneIds array

@description('Optional. Custom name for the DNS zone group. Defaults to `default`.')
param dnsZoneGroupName string = 'default'

@description('Tags applied to the PE.')
param tags object = {}

resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-conn'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: subresourceNames
        }
      }
    ]
  }
}

resource dnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(privateDnsZoneIds)) {
  parent: pe
  name: dnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [for (id, i) in privateDnsZoneIds: {
      name: 'config-${i}'
      properties: {
        privateDnsZoneId: id
      }
    }]
  }
}

output id string = pe.id
output name string = pe.name
