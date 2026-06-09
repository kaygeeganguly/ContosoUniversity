// ============================================================
// User-Assigned Managed Identity
// ============================================================
param location string
param resourceToken string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'azmi${resourceToken}'
  location: location
}

output id string = managedIdentity.id
output clientId string = managedIdentity.properties.clientId
output principalId string = managedIdentity.properties.principalId
output name string = managedIdentity.name
