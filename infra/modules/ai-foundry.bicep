// Azure AI Foundry Module (Azure OpenAI)
// Provides GPT-4 and Phi model access for AI capabilities

@description('Location for the AI Foundry resource')
param location string

@description('Name of the Azure AI Foundry account')
param aiFoundryName string

@description('Principal ID of the managed identity for Cognitive Services User role')
param managedIdentityPrincipalId string

@description('Tags to apply to resources')
param tags object = {}

// =============================================
// Variables
// =============================================

// Cognitive Services User role definition ID
var cognitiveServicesUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')

// =============================================
// Azure OpenAI (AI Foundry)
// =============================================

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: aiFoundryName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: aiFoundryName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false // Can be set to true for enhanced security
  }
}

// =============================================
// GPT-4o Model Deployment (Available in westus3)
// =============================================

resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: aiFoundry
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 10 // Tokens per minute in thousands
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-08-06'
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

// =============================================
// GPT-4o-mini Model Deployment (Cost-effective alternative)
// =============================================

resource gpt4MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: aiFoundry
  name: 'gpt-4o-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    raiPolicyName: 'Microsoft.Default'
  }
  dependsOn: [
    gpt4Deployment // Deploy sequentially to avoid conflicts
  ]
}

// =============================================
// Role Assignment - Cognitive Services User
// =============================================

resource cognitiveServicesUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry.id, managedIdentityPrincipalId, cognitiveServicesUserRoleId)
  scope: aiFoundry
  properties: {
    principalId: managedIdentityPrincipalId
    roleDefinitionId: cognitiveServicesUserRoleId
    principalType: 'ServicePrincipal'
  }
}

// =============================================
// Outputs
// =============================================

output id string = aiFoundry.id
output name string = aiFoundry.name
output endpoint string = aiFoundry.properties.endpoint
output gpt4DeploymentName string = gpt4Deployment.name
output gpt4MiniDeploymentName string = gpt4MiniDeployment.name
