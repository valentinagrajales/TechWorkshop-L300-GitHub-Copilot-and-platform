// User-Assigned Managed Identity Module
// Provides identity for RBAC-based authentication across Azure services

@description('Location for the managed identity')
param location string

@description('Name of the managed identity')
param identityName string

@description('Tags to apply to resources')
param tags object = {}

// =============================================
// User-Assigned Managed Identity
// =============================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

// =============================================
// Outputs
// =============================================

output identityId string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
output name string = managedIdentity.name
