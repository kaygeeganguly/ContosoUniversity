// modules/containerapp.bicep
// Azure Container Apps Environment (Consumption) + Container App
// Rules applied:
//   - User-Assigned Managed Identity attached
//   - Container registry connected via managed identity (NOT system-assigned)
//   - AcrPull role assignment must exist BEFORE this module (handled in main.bicep dependsOn)
//   - Base image: mcr.microsoft.com/azuredocs/containerapps-helloworld:latest
//   - CORS enabled on ingress
//   - Log Analytics workspace connected

param location string
param resourceToken string

@description('Full resource ID of the user-assigned managed identity')
param managedIdentityId string

@description('Client ID of the user-assigned managed identity (for DefaultAzureCredential)')
param managedIdentityClientId string

@description('Log Analytics workspace customer ID')
param logAnalyticsCustomerId string

@description('Log Analytics workspace shared key')
@secure()
param logAnalyticsSharedKey string

@description('ACR login server (e.g. azacr<token>.azurecr.io)')
param acrLoginServer string

@description('Service Bus fully-qualified namespace (e.g. azsb<token>.servicebus.windows.net)')
param serviceBusFqdn string

@description('Azure Blob Storage service URI (e.g. https://azst<token>.blob.core.windows.net)')
param storageServiceUri string

@description('Blob container name for teaching materials')
param storageContainerName string

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'azcae${resourceToken}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'azca${resourceToken}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
      // Registry connection via managed identity — required even with base image
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      // Use approved base image per IaC rules; replaced at application deployment time
      containers: [
        {
          name: 'contosouniversity'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            // Managed Identity client ID — consumed by DefaultAzureCredential in SDK
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentityClientId
            }
            // Azure Service Bus FQDN — overrides appsettings.json placeholder
            {
              name: 'AzureServiceBus__FullyQualifiedNamespace'
              value: serviceBusFqdn
            }
            // Azure Blob Storage URI — overrides appsettings.json placeholder
            {
              name: 'Storage__ServiceUri'
              value: storageServiceUri
            }
            // Blob container name — overrides appsettings.json
            {
              name: 'Storage__ContainerName'
              value: storageContainerName
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}

output environmentName string = containerAppsEnvironment.name
output environmentId string = containerAppsEnvironment.id
output appName string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output appId string = containerApp.id
