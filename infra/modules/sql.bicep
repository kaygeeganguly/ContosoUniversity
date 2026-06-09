// ============================================================
// Azure SQL Server + Database + Firewall rules
// Rule: Firewall must allow Azure services (0.0.0.0)
// Rule: Using Managed Identity → post-provision Service Connector step required
// ============================================================
param location string
param resourceToken string

@description('SQL Server administrator login')
param adminLogin string

@description('SQL Server administrator password')
@secure()
param adminPassword string

resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = {
  name: 'azsql${resourceToken}'
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-02-01-preview' = {
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
    maxSizeBytes: 34359738368
    autoPauseDelay: 60
    // BCP036: minCapacity is a decimal (0.5 vCore) — type definition inaccuracy in Bicep for this SQL property
    #disable-next-line BCP036
    minCapacity: '0.5'
    requestedBackupStorageRedundancy: 'Local'
  }
}

// MANDATORY: Allow traffic from Azure Services (start & end IP = 0.0.0.0)
resource sqlFirewallAllowAzure 'Microsoft.Sql/servers/firewallRules@2023-02-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output serverName string = sqlServer.name
output databaseName string = sqlDatabase.name
output serverId string = sqlServer.id
