// modules/storage.bicep
// Azure Storage Account (Standard LRS) + Blob container + Blob Data Contributor role
// Rules applied:
//   - Local auth (shared key) disabled
//   - Anonymous blob access disabled
//   - HTTPS-only, TLS 1.2+

param location string
param resourceToken string
param managedIdentityPrincipalId string

var storageBlobDataContributorRoleDefinitionId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'azst${resourceToken}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false          // disable anonymous blob access
    allowSharedKeyAccess: false           // disable local auth (key access)
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource teachingMaterialsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'teaching-materials'
  properties: {
    publicAccess: 'None'
  }
}

// Storage Blob Data Contributor — grants full blob read/write for managed identity
resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentityPrincipalId, storageBlobDataContributorRoleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleDefinitionId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output accountName string = storageAccount.name
output serviceUri string = 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
output containerName string = teachingMaterialsContainer.name
output storageAccountId string = storageAccount.id
