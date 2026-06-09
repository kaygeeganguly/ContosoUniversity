// ============================================================
// main.bicep — ContosoUniversity Infrastructure
// Provisions: Managed Identity, Log Analytics, ACR, SQL Database,
//             Service Bus, Storage Account, Container Apps
// Region: centralus (selected from available regions)
// Naming: az{prefix}{resourceToken} per IaC naming rules
// ============================================================
targetScope = 'resourceGroup'

@description('Environment name used for resource token generation and naming')
param environmentName string

@description('Azure region for all resources. Must be one of the available regions.')
param location string = 'centralus'

@description('SQL Server administrator login name')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

// Resource token: uniqueString scoped to subscription + resource group + location + environment
// Format per IaC rules: uniqueString(subscription().id, resourceGroup().id, location, environmentName)
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)

// ── Managed Identity ─────────────────────────────────────────
module identity 'modules/identity.bicep' = {
  name: 'identity-deploy'
  params: {
    location: location
    resourceToken: resourceToken
  }
}

// ── Log Analytics Workspace ───────────────────────────────────
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics-deploy'
  params: {
    location: location
    resourceToken: resourceToken
  }
}

// ── Container Registry + AcrPull role ────────────────────────
// IMPORTANT: Must be defined BEFORE container apps per rules
module acr 'modules/acr.bicep' = {
  name: 'acr-deploy'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// ── SQL Server + Database + Firewall ─────────────────────────
module sql 'modules/sql.bicep' = {
  name: 'sql-deploy'
  params: {
    location: location
    resourceToken: resourceToken
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
  }
}

// ── Service Bus + Queue + Data Owner role ─────────────────────
module servicebus 'modules/servicebus.bicep' = {
  name: 'servicebus-deploy'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// ── Storage Account + Container + Blob Contributor role ───────
module storage 'modules/storage.bicep' = {
  name: 'storage-deploy'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// ── Container Apps Environment + Container App ────────────────
module containerapp 'modules/containerapp.bicep' = {
  name: 'containerapp-deploy'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityId: identity.outputs.id
    managedIdentityClientId: identity.outputs.clientId
    acrLoginServer: acr.outputs.loginServer
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsSharedKey: logAnalytics.outputs.sharedKey
    serviceBusNamespace: servicebus.outputs.fullyQualifiedNamespace
    serviceBusQueueName: servicebus.outputs.queueName
    storageServiceUri: storage.outputs.serviceUri
    storageContainerName: storage.outputs.containerName
  }
}

// ── Outputs ───────────────────────────────────────────────────
output containerAppFqdn string = containerapp.outputs.containerAppFqdn
output containerAppName string = containerapp.outputs.containerAppName
output containerAppEnvName string = containerapp.outputs.containerAppEnvName
output sqlServerFqdn string = sql.outputs.serverFqdn
output sqlServerName string = sql.outputs.serverName
output sqlDatabaseName string = sql.outputs.databaseName
output serviceBusNamespace string = servicebus.outputs.fullyQualifiedNamespace
output serviceBusQueueName string = servicebus.outputs.queueName
output storageAccountName string = storage.outputs.accountName
output storageServiceUri string = storage.outputs.serviceUri
output acrLoginServer string = acr.outputs.loginServer
output acrName string = acr.outputs.name
output managedIdentityClientId string = identity.outputs.clientId
output managedIdentityName string = identity.outputs.name
output managedIdentityId string = identity.outputs.id
output resourceToken string = resourceToken
