// Main Bicep template for ZavaStorefront Azure Infrastructure
// Deploys: App Service, ACR, Application Insights, Log Analytics, Azure AI Foundry, Managed Identity

targetScope = 'subscription'

// =============================================
// Parameters
// =============================================

@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g., dev, staging, prod)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'westus3'

@description('Name of the resource group')
param resourceGroupName string = 'rg-${environmentName}'

@description('Name of the App Service (optional, auto-generated if not provided)')
param appServiceName string = ''

@description('Name of the Container Registry (optional, auto-generated if not provided)')
param containerRegistryName string = ''

@description('Name of the Log Analytics Workspace (optional, auto-generated if not provided)')
param logAnalyticsName string = ''

@description('Name of the Application Insights (optional, auto-generated if not provided)')
param applicationInsightsName string = ''

@description('Name of the Azure AI Foundry account (optional, auto-generated if not provided)')
param aiFoundryName string = ''

// =============================================
// Variables
// =============================================

// Generate unique resource token for naming
var resourceToken = uniqueString(subscription().id, location, environmentName)

// Resource names with proper prefixes (max 32 chars, alphanumeric)
var abbrs = {
  appService: 'azapp'
  containerRegistry: 'azacr'
  logAnalytics: 'azlog'
  applicationInsights: 'azai'
  aiFoundry: 'azoai'
  managedIdentity: 'azid'
}

// =============================================
// Resource Group
// =============================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

// =============================================
// Module Deployments
// =============================================

// User-Assigned Managed Identity
module identity 'modules/identity.bicep' = {
  name: 'identity-deployment'
  scope: rg
  params: {
    location: location
    identityName: '${abbrs.managedIdentity}${resourceToken}'
    tags: {
      'azd-env-name': environmentName
    }
  }
}

// Log Analytics Workspace
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  scope: rg
  params: {
    location: location
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.logAnalytics}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.applicationInsights}${resourceToken}'
    tags: {
      'azd-env-name': environmentName
    }
  }
}

// Azure Container Registry
module acr 'modules/acr.bicep' = {
  name: 'acr-deployment'
  scope: rg
  params: {
    location: location
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistry}${resourceToken}'
    managedIdentityPrincipalId: identity.outputs.principalId
    tags: {
      'azd-env-name': environmentName
    }
  }
}

// Azure AI Foundry (Azure OpenAI)
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    location: location
    aiFoundryName: !empty(aiFoundryName) ? aiFoundryName : '${abbrs.aiFoundry}${resourceToken}'
    managedIdentityPrincipalId: identity.outputs.principalId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    tags: {
      'azd-env-name': environmentName
    }
  }
}

// App Service
module appService 'modules/appservice.bicep' = {
  name: 'appservice-deployment'
  scope: rg
  params: {
    location: location
    appServiceName: !empty(appServiceName) ? appServiceName : '${abbrs.appService}${resourceToken}'
    managedIdentityId: identity.outputs.identityId
    managedIdentityClientId: identity.outputs.clientId
    containerRegistryLoginServer: acr.outputs.loginServer
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    aiFoundryEndpoint: aiFoundry.outputs.endpoint
    environmentName: environmentName
    tags: {
      'azd-env-name': environmentName
      'azd-service-name': 'web'
    }
  }
}

// =============================================
// Outputs
// =============================================

output RESOURCE_GROUP_ID string = rg.id
output RESOURCE_GROUP_NAME string = rg.name
output AZURE_LOCATION string = location

// App Service outputs
output APP_SERVICE_NAME string = appService.outputs.name
output APP_SERVICE_URL string = appService.outputs.url

// Container Registry outputs
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.loginServer

// Monitoring outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName

// AI Foundry outputs
output AZURE_OPENAI_ENDPOINT string = aiFoundry.outputs.endpoint
output AZURE_OPENAI_NAME string = aiFoundry.outputs.name

// Managed Identity outputs
output AZURE_MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.clientId
