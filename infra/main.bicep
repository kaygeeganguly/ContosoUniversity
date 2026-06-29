// main.bicep — ContosoUniversity Infrastructure
// Orchestrates all modules to provision required Azure resources.
// Naming convention: az{prefix}{resourceToken} per IaC rules.
// Region: swedencentral (selected based on quota availability)

targetScope = 'resourceGroup'

// ── Parameters ──────────────────────────────────────────────────────────────

@description('Short environment label used in resource naming (e.g. dev, test, prod)')
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = 'centralus'

@description('Object ID of the Azure AD user/group to assign as SQL Server Azure AD administrator')
param sqlAadAdminObjectId string

@description('Display name or UPN of the SQL Server Azure AD administrator')
param sqlAadAdminLogin string

// ── Resource Token ───────────────────────────────────────────────────────────
// Unique 13-char string scoped to subscription + resource group + location + env
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)

// ── Module: User-Assigned Managed Identity ───────────────────────────────────
module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
    resourceToken: resourceToken
  }
}

// ── Module: Azure Container Registry ─────────────────────────────────────────
// AcrPull role assignment is created INSIDE registry module (defined BEFORE containerapp)
module registry 'modules/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// ── Module: Log Analytics Workspace ──────────────────────────────────────────
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    location: location
    resourceToken: resourceToken
  }
}

// ── Module: Azure SQL Server + Database ──────────────────────────────────────
module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    location: location
    resourceToken: resourceToken
    sqlAadAdminObjectId: sqlAadAdminObjectId
    sqlAadAdminLogin: sqlAadAdminLogin
  }
}

// ── Module: Azure Service Bus ─────────────────────────────────────────────────
module serviceBus 'modules/servicebus.bicep' = {
  name: 'servicebus'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// ── Module: Azure Storage Account ────────────────────────────────────────────
module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// ── Module: Container Apps Environment + Container App ───────────────────────
// dependsOn registry ensures AcrPull role assignment is complete before container app
module containerApp 'modules/containerapp.bicep' = {
  name: 'containerapp'
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityId: identity.outputs.id
    managedIdentityClientId: identity.outputs.clientId
    logAnalyticsCustomerId: logAnalytics.outputs.customerId
    logAnalyticsSharedKey: logAnalytics.outputs.sharedKey
    acrLoginServer: registry.outputs.loginServer
    serviceBusFqdn: serviceBus.outputs.fullyQualifiedNamespace
    storageServiceUri: storage.outputs.serviceUri
    storageContainerName: storage.outputs.containerName
  }
}


// ── Outputs ──────────────────────────────────────────────────────────────────
output managedIdentityClientId string = identity.outputs.clientId
output managedIdentityName string = identity.outputs.name
output acrLoginServer string = registry.outputs.loginServer
output acrName string = registry.outputs.name
output sqlServerName string = sql.outputs.serverName
output sqlServerFqdn string = sql.outputs.fqdn
output sqlDatabaseName string = sql.outputs.databaseName
output serviceBusNamespace string = serviceBus.outputs.namespaceName
output serviceBusFqdn string = serviceBus.outputs.fullyQualifiedNamespace
output storageAccountName string = storage.outputs.accountName
output storageServiceUri string = storage.outputs.serviceUri
output containerAppName string = containerApp.outputs.appName
output containerAppFqdn string = containerApp.outputs.fqdn
output containerAppId string = containerApp.outputs.appId
output resourceGroupName string = resourceGroup().name
output subscriptionId string = subscription().id
