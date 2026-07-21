// ============================================================================
// VNet + subnets -- v1
//
// Creates one VNet, then declares each subnet as a child resource so
// bicep can loop over the subnet map without hitting BCP138 (nested for
// expressions on the inline VNet.subnets property).
//
// The `subnets` param is a map whose values are objects with:
//   - name             (string, required)
//   - addressPrefixes  (string[], required)
//   - delegations      (optional; array of { name, serviceName })
// ============================================================================

@description('VNet name.')
param name string

@description('Azure location for the VNet.')
param location string = resourceGroup().location

@description('Address space CIDR blocks for the VNet.')
param addressSpace array

@description('Map of logical subnet key -> subnet definition.')
param subnets object

@description('Tags applied to the VNet.')
param tags object = {}

// ----------------------------------------------------------------------------
// VNet (no inline subnets -- child resources declared below)
// ----------------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
    // NB: no inline `subnets` array. Subnets are managed as child resources
    // below. Setting `subnets: []` here would race with the child-resource
    // loop and can wipe subnets on subsequent VNet PUTs.
  }
}

// ----------------------------------------------------------------------------
// Child subnet resources -- looped over the input map. Delegations are
// applied per subnet without nesting a for-expression inside the VNet body.
// ----------------------------------------------------------------------------

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [for key in items(subnets): {
  parent: vnet
  name: key.value.name
  properties: {
    addressPrefixes: key.value.addressPrefixes
    delegations: contains(key.value, 'delegations') ? key.value.delegations : []
    // PE + agent subnets historically default privateEndpointNetworkPolicies
    // to Disabled. Keep that platform default so both PE and network-injection
    // scenarios "just work".
    privateEndpointNetworkPolicies: 'Disabled'
  }
}]

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output id string = vnet.id
output name string = vnet.name

// Map of logical key -> subnet resource id (mirrors the Terraform subnet
// module output for parity with the workload stack's data-lookup patterns).
output subnetIds object = toObject(items(subnets), k => k.key, k => resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, k.value.name))
output subnetNames object = toObject(items(subnets), k => k.key, k => k.value.name)
