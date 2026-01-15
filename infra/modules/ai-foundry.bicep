// Azure AI Foundry Module (Azure OpenAI)
// Provides GPT-4 model access for AI capabilities
// 
// SECURITY: This module enforces identity-only authentication (Microsoft Entra ID)
// - API keys are fully disabled via disableLocalAuth: true
// - All authentication must use Managed Identity or Microsoft Entra ID tokens
// - The Cognitive Services User role is assigned to the managed identity for access

@description('Location for the AI Foundry resource')
param location string

@description('Name of the Azure AI Foundry account')
param aiFoundryName string

@description('Principal ID of the managed identity for Cognitive Services User role')
param managedIdentityPrincipalId string

@description('Resource ID of the Log Analytics Workspace for diagnostic settings')
param logAnalyticsWorkspaceId string

@description('Tags to apply to resources')
param tags object = {}

// =============================================
// Variables
// =============================================

// Cognitive Services User role definition ID - Required for identity-based access to Azure OpenAI
// This role allows the identity to call Azure OpenAI APIs without API keys
var cognitiveServicesUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')

// =============================================
// Azure OpenAI (AI Foundry)
// IDENTITY-ONLY AUTHENTICATION ENFORCED
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
      // Azure services can bypass network rules when using managed identity
      bypass: 'AzureServices'
    }
    // CRITICAL: Disable API key authentication - Microsoft Entra ID is the only supported auth method
    // When true, any requests using API keys (Ocp-Apim-Subscription-Key header) will be rejected
    // Clients must authenticate using Azure.Identity (DefaultAzureCredential, ManagedIdentityCredential, etc.)
    disableLocalAuth: true
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
// REQUIRED for identity-only authentication
// This grants the managed identity permission to call Azure OpenAI APIs
// Without this role, even with valid Entra ID tokens, API calls will fail with 403
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
// Diagnostic Settings
// Sends all available log categories and metrics to Log Analytics
// =============================================

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aiFoundryName}-diagnostics'
  scope: aiFoundry
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'RequestResponse'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Trace'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AzureOpenAIRequestUsage'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// =============================================
// Outputs
// =============================================

// Endpoint URL for Azure OpenAI - use with DefaultAzureCredential for authentication
output id string = aiFoundry.id
output name string = aiFoundry.name
output endpoint string = aiFoundry.properties.endpoint
output gpt4DeploymentName string = gpt4Deployment.name
output gpt4MiniDeploymentName string = gpt4MiniDeployment.name

// Output to confirm identity-only authentication is enforced
output localAuthDisabled bool = aiFoundry.properties.disableLocalAuth
