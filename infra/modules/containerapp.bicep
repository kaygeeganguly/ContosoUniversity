// ============================================================
// Azure Container Apps Environment + Container App
// Rules applied:
//   - User-Assigned Managed Identity attached
//   - Base image: mcr.microsoft.com/azuredocs/containerapps-helloworld:latest
//   - ACR registry connection via properties.configuration.registries + identity
//   - CORS enabled via properties.configuration.ingress.corsPolicy
//   - Environment connected to Log Analytics Workspace
// ============================================================
param location string
param resourceToken string

@description('Resource ID of the user-assigned managed identity')
param managedIdentityId string

@description('Client ID of the user-assigned managed identity')
param managedIdentityClientId string

@description('ACR login server (e.g. azacrXXXX.azurecr.io)')
param acrLoginServer string

@description('Log Analytics workspace customer ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics workspace shared key')
@secure()
param logAnalyticsSharedKey string

@description('Azure Service Bus fully qualified namespace')
param serviceBusNamespace string

@description('Azure Service Bus queue name')
param serviceBusQueueName string

@description('Azure Storage blob service URI')
param storageServiceUri string

@description('Azure Storage blob container name')
param storageContainerName string

// Container Apps Environment (Consumption plan) with Log Analytics
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'azcae${resourceToken}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceId
        sharedKey: logAnalyticsSharedKey
      }
    }
  }
}

// Container App — base hello-world image (replaced in task 008 with actual app image)
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'azca${resourceToken}'
  location: location
  // MANDATORY: Attach User-Assigned Managed Identity
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      // MANDATORY: Registry connection using managed identity (NOT password)
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        // MANDATORY: Enable CORS
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD', 'PATCH']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
    }
    template: {
      containers: [
        {
          // MANDATORY: Base container image per rules
          name: 'contosouniversity'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            // Managed Identity client ID so DefaultAzureCredential picks correct identity
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentityClientId
            }
            // Service Bus configuration
            {
              name: 'AzureServiceBus__FullyQualifiedNamespace'
              value: serviceBusNamespace
            }
            {
              name: 'AzureServiceBus__QueueName'
              value: serviceBusQueueName
            }
            // Storage configuration
            {
              name: 'Storage__ServiceUri'
              value: storageServiceUri
            }
            {
              name: 'Storage__ContainerName'
              value: storageContainerName
            }
            // NOTE: ConnectionStrings__DefaultConnection is set by
            // Service Connector post-provision step (az containerapp connection create sql)
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
output containerAppName string = containerApp.name
output containerAppId string = containerApp.id
output containerAppEnvName string = containerAppEnv.name
output containerAppEnvId string = containerAppEnv.id
