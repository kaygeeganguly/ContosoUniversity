// modules/sql.bicep
// Azure SQL Server + General Purpose Serverless Database + Azure services firewall rule
// Policy compliance: Azure AD-only authentication (no SQL auth) per MCAPS policy
//   AzureSQL_WithoutAzureADOnlyAuthentication_Deny

param location string
param resourceToken string

@description('Object ID of the Azure AD user/group/service-principal to set as SQL AD admin')
param sqlAadAdminObjectId string

@description('Display name or UPN of the Azure AD admin (e.g. user@tenant.onmicrosoft.com)')
param sqlAadAdminLogin string

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: 'azsql${resourceToken}'
  location: location
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    // Azure AD-only authentication — satisfies MCAPS policy
    administrators: {
      administratorType: 'ActiveDirectory'
      login: sqlAadAdminLogin
      sid: sqlAadAdminObjectId
      tenantId: tenant().tenantId
      azureADOnlyAuthentication: true
    }
  }
}

// General Purpose Serverless — auto-pauses to minimise cost
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: 'ContosoUniversity'
  location: location
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    autoPauseDelay: 60
    minCapacity: any('0.5')
  }
}

// Allow traffic from Azure Services (IP 0.0.0.0/0.0.0.0)
resource firewallRuleAzureServices 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output serverName string = sqlServer.name
output fqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = sqlDatabase.name
output serverId string = sqlServer.id
