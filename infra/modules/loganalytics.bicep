// modules/loganalytics.bicep
// Log Analytics Workspace — required sink for Container Apps Environment logging

param location string
param resourceToken string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'azlog${resourceToken}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

output customerId string = logAnalytics.properties.customerId
#disable-next-line outputs-should-not-contain-secrets
output sharedKey string = logAnalytics.listKeys().primarySharedKey
output id string = logAnalytics.id
output name string = logAnalytics.name
