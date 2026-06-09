// ============================================================
// Azure Storage Account + Blob Container + Blob Contributor role
// Rule: Disable local auth (allowSharedKeyAccess = false)
// Rule: Disable anonymous blob access (allowBlobPublicAccess = false)
// ============================================================
param location string
param resourceToken string
param managedIdentityPrincipalId string

// Storage Blob Data Contributor built-in role ID
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'azst${resourceToken}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // MANDATORY: Disable local auth (shared key access)
    allowSharedKeyAccess: false
    // MANDATORY: Disable anonymous blob access
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Blob container for teaching materials
resource teachingMaterialsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'teaching-materials'
  properties: {
    publicAccess: 'None'
  }
}

// Storage Blob Data Contributor role for the managed identity
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentityPrincipalId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output accountName string = storageAccount.name
output serviceUri string = storageAccount.properties.primaryEndpoints.blob
output containerName string = teachingMaterialsContainer.name
output accountId string = storageAccount.id
