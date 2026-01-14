// Azure App Service Module
// Hosts the ZavaStorefront .NET 6 application

@description('Location for the App Service')
param location string

@description('Name of the App Service')
param appServiceName string

@description('User-Assigned Managed Identity resource ID')
param managedIdentityId string

@description('User-Assigned Managed Identity client ID')
param managedIdentityClientId string

@description('Container Registry login server URL')
param containerRegistryLoginServer string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

@description('Azure AI Foundry endpoint')
param aiFoundryEndpoint string

@description('Environment name for configuration')
param environmentName string

@description('Tags to apply to resources')
param tags object = {}

@description('Tags specifically for the App Service (includes azd-service-name)')
param appServiceTags object = {}

// =============================================
// Variables
// =============================================

var appServicePlanName = '${appServiceName}-plan'
var aspNetCoreEnv = environmentName == 'prod' ? 'Production' : 'Development'
// Plan tags should NOT include azd-service-name
var planTags = contains(tags, 'azd-service-name') ? reduce(items(tags), {}, (acc, item) => item.key == 'azd-service-name' ? acc : union(acc, { '${item.key}': item.value })) : tags

// =============================================
// App Service Plan
// =============================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: planTags
  kind: 'linux'
  sku: {
    name: 'B1' // Basic tier - cost-effective for dev
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// =============================================
// App Service
// =============================================

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0' // .NET 8.0 runtime for container deployment
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentityClientId
      alwaysOn: false // Can be disabled for dev to save costs
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: aspNetCoreEnv
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: aiFoundryEndpoint
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentityClientId
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistryLoginServer}'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

// Note: Site extensions are NOT supported on Linux App Services
// Application Insights is enabled via APPLICATIONINSIGHTS_CONNECTION_STRING app setting

// =============================================
// Outputs
// =============================================

output id string = appService.id
output name string = appService.name
output url string = 'https://${appService.properties.defaultHostName}'
output principalId string = appService.identity.userAssignedIdentities[managedIdentityId].principalId
