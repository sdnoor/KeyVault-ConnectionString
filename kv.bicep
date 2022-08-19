
param location string
@allowed([
  'dev'
  'prod'
])
param environmentType string

param adminLogin string = 'cebsdevops'
@secure()
param adminPassw string

param danishTimeZone string

param keyVaultName string
param keyVaultRGName string
param dbConnectionString string


var storageAccountName = 'stowesteu${uniqueString(resourceGroup().id)}'

var appServicePlanName = 'appSP-westeu-${environmentType}'

var appServicePlanSkuName = environmentType == 'dev' ? 'P2v3' : 'F1'

var sqlServerName = 'sql-westeu-${environmentType}'

var sqlDbName = 'db-westeu-${environmentType}'

var functionAppName = 'func-westeu-${environmentType}'



resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSkuName
  }
}
resource sqlServer 'Microsoft.Sql/servers@2021-08-01-preview' ={
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassw
  }
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2021-08-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  properties: {
  }
  sku: {
    name: 'S1'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultRGName)
  }

  resource azureFunction 'Microsoft.Web/sites@2020-12-01' = {
    name: functionAppName
    location: location
    kind: 'functionapp'
    properties: {
      serverFarmId: appServicePlan.id
      siteConfig: {
        appSettings: [
          {
            name: 'AzureWebJobsDashboard'
            value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccount.id, '2019-06-01').keys[0].value}'
          }
          {
            name: 'AzureWebJobsStorage'
            value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccount.id, '2019-06-01').keys[0].value}'
          }
          {
            name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
            value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccount.id, '2019-06-01').keys[0].value}'
          }
          {
            name: 'WEBSITE_CONTENTSHARE'
            value: toLower(functionAppName)
          }
          {
            name: 'FUNCTIONS_EXTENSION_VERSION'
            value: '~2'
          }
          {
            name: 'WEBSITE_TIME_ZONE'
            value: danishTimeZone
          }
          {
            name: 'FUNCTIONS_WORKER_RUNTIME'
            value: 'dotnet'
          }
        ]
        connectionStrings:[
          {
            name: 'connectionstring'
            connectionString: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${dbConnectionString})'
            type: 'SQLAzure'
          }
        ]
      }
    }
  }

