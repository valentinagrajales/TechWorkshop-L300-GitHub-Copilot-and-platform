// Monitoring Module - Application Insights and Log Analytics
// Provides observability for the ZavaStorefront application

@description('Location for the resources')
param location string

@description('Name of the Log Analytics Workspace')
param logAnalyticsName string

@description('Name of Application Insights')
param applicationInsightsName string

@description('Tags to apply to resources')
param tags object = {}

// =============================================
// Log Analytics Workspace
// =============================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30 // Cost-effective for dev environment
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1 // Limit daily ingestion for dev
    }
  }
}

// =============================================
// Application Insights
// =============================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: 30
  }
}

// =============================================
// Outputs
// =============================================

output logAnalyticsId string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output applicationInsightsId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
