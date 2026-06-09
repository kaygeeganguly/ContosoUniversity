// ============================================================
// Azure Service Bus Namespace (Standard) + Queue + Data Owner role
// ============================================================
param location string
param resourceToken string
param managedIdentityPrincipalId string

// Azure Service Bus Data Owner built-in role ID
var serviceBusDataOwnerRoleId = '090c5cfd-751d-6522-c04e-b6028e3b2e5c'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'azsb${resourceToken}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
    disableLocalAuth: false
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'contoso-notifications'
  properties: {
    lockDuration: 'PT1M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: false
    enableBatchedOperations: true
    maxDeliveryCount: 10
    enablePartitioning: false
    enableExpress: false
  }
}

// Azure Service Bus Data Owner role for the managed identity
resource serviceBusDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBusNamespace.id, managedIdentityPrincipalId, serviceBusDataOwnerRoleId)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataOwnerRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output fullyQualifiedNamespace string = '${serviceBusNamespace.name}.servicebus.windows.net'
output namespaceName string = serviceBusNamespace.name
output queueName string = serviceBusQueue.name
output namespaceId string = serviceBusNamespace.id
