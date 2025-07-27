// ================================================================================================
// AZURE AUTOMATION ACCOUNT WITH HYBRID WORKER GROUP AND RUNBOOKS
// ================================================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Automation Account')
param automationAccountName string = 'aa-${uniqueString(resourceGroup().id)}'

@description('Name of the hybrid worker group')
param hybridWorkerGroupName string = 'HybridWorkerGroup'

@description('Resource ID of the existing VM to add to hybrid worker group')
param existingVmResourceId string

@description('Resource group name where the existing VM is located')
param existingVmResourceGroupName string

@description('Name of the existing VM')
param existingVmName string

@description('First runbook name')
param runbook1Name string = 'Get-SystemInfo'

@description('Second runbook name')
param runbook2Name string = 'Restart-Service'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Demo'
  Project: 'AutomationWithHybridWorker'
}

// ================================================================================================
// VARIABLES
// ================================================================================================

var logAnalyticsWorkspaceName = 'law-${uniqueString(resourceGroup().id)}'

// ================================================================================================
// LOG ANALYTICS WORKSPACE
// ================================================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ================================================================================================
// AUTOMATION ACCOUNT
// ================================================================================================

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    publicNetworkAccess: true
    disableLocalAuth: false
  }
}

// ================================================================================================
// LINK AUTOMATION ACCOUNT TO LOG ANALYTICS
// ================================================================================================

resource automationSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Automation(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  plan: {
    name: 'Automation(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/Automation'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource linkedService 'Microsoft.OperationalInsights/workspaces/linkedServices@2020-08-01' = {
  parent: logAnalyticsWorkspace
  name: 'Automation'
  properties: {
    resourceId: automationAccount.id
  }
  dependsOn: [
    automationSolution
  ]
}

// ================================================================================================
// HYBRID WORKER GROUP
// ================================================================================================

resource hybridWorkerGroup 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups@2022-08-08' = {
  parent: automationAccount
  name: hybridWorkerGroupName
  properties: {
    groupType: 'User'
  }
}

// ================================================================================================
// HYBRID WORKER (ADD EXISTING VM)
// ================================================================================================

// Reference to existing VM
resource existingVm 'Microsoft.Compute/virtualMachines@2023-09-01' existing = {
  name: existingVmName
  scope: resourceGroup(existingVmResourceGroupName)
}

// Install Hybrid Worker Extension on existing VM
resource hybridWorkerExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  name: 'HybridWorkerExtension'
  parent: existingVm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Automation.HybridWorker'
    type: 'HybridWorkerForWindows'
    typeHandlerVersion: '1.1'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AutomationAccountURL: automationAccount.properties.automationHybridServiceUrl
    }
  }
  dependsOn: [
    hybridWorkerGroup
  ]
}

// Add VM to Hybrid Worker Group
resource hybridWorker 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups/hybridRunbookWorkers@2022-08-08' = {
  parent: hybridWorkerGroup
  name: existingVmName
  properties: {
    vmResourceId: existingVmResourceId
  }
  dependsOn: [
    hybridWorkerExtension
  ]
}

// ================================================================================================
// RUNBOOK 1: GET SYSTEM INFO
// ================================================================================================

resource runbook1 'Microsoft.Automation/automationAccounts/runbooks@2020-01-13-preview' = {
  parent: automationAccount
  name: runbook1Name
  properties: {
    runbookType: 'PowerShell'
    logVerbose: true
    logProgress: true
    description: 'Gets system information from the hybrid worker'
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/user/repo/main/empty.ps1'
      version: '1.0.0.0'
    }
  }
}

// ================================================================================================
// RUNBOOK 2: RESTART SERVICE
// ================================================================================================

resource runbook2 'Microsoft.Automation/automationAccounts/runbooks@2020-01-13-preview' = {
  parent: automationAccount
  name: runbook2Name
  properties: {
    runbookType: 'PowerShell'
    logVerbose: true
    logProgress: true
    description: 'Restarts a specified Windows service on the hybrid worker'
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/user/repo/main/empty.ps1'
      version: '1.0.0.0'
    }
  }
}

// ================================================================================================
// ROLE ASSIGNMENTS
// ================================================================================================

// Assign Automation Contributor role to the Automation Account's managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, automationAccount.id, 'AutomationContributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f353d9bd-d4a6-484e-a77a-8050b599b867')
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign Virtual Machine Contributor role for managing VMs
resource vmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, automationAccount.id, 'VirtualMachineContributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ================================================================================================
// OUTPUTS
// ================================================================================================

@description('Resource ID of the Automation Account')
output automationAccountId string = automationAccount.id

@description('Name of the Automation Account')
output automationAccountName string = automationAccount.name

@description('Name of the Hybrid Worker Group')
output hybridWorkerGroupName string = hybridWorkerGroup.name

@description('Automation Account Hybrid Service URL')
output automationHybridServiceUrl string = automationAccount.properties.automationHybridServiceUrl

@description('Resource ID of the Log Analytics Workspace')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('First runbook name')
output runbook1Name string = runbook1.name

@description('Second runbook name')
output runbook2Name string = runbook2.name

@description('Automation Account Managed Identity Principal ID')
output automationAccountPrincipalId string = automationAccount.identity.principalId