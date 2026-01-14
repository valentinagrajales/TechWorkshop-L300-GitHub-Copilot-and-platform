// Azure Container Registry Module
// Stores Docker images for the ZavaStorefront application

@description('Location for the container registry')
param location string

@description('Name of the container registry')
param containerRegistryName string

@description('Principal ID of the managed identity for AcrPull role assignment')
param managedIdentityPrincipalId string

@description('Tags to apply to resources')
param tags object = {}

// =============================================
// Variables
// =============================================

// AcrPull role definition ID
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// =============================================
// Azure Container Registry
// =============================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: 'Basic' // Cost-effective for dev environment
  }
  properties: {
    adminUserEnabled: false // Use RBAC instead of admin credentials
    anonymousPullEnabled: false // Security: disable anonymous pull
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled' // Not needed for dev
  }
}

// =============================================
// Role Assignment - AcrPull for Managed Identity
// =============================================

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentityPrincipalId, acrPullRoleDefinitionId)
  scope: containerRegistry
  properties: {
    principalId: managedIdentityPrincipalId
    roleDefinitionId: acrPullRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

// =============================================
// Outputs
// =============================================

output id string = containerRegistry.id
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
