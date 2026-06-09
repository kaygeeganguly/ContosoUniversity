// ============================================================
// Log Analytics Workspace (required by Container Apps environment)
// ============================================================
param location string
param resourceToken string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'azlaw${resourceToken}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceId string = logAnalyticsWorkspace.properties.customerId
@secure()
output sharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey
output name string = logAnalyticsWorkspace.name
