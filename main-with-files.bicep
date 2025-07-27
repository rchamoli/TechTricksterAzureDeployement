@description('The name of the Automation Account')
param automationAccountName string

@description('The name of the Hybrid Worker Group')
param hybridWorkerGroupName string = 'DefaultWorkerGroup'

@description('The name of the existing VM to add as a hybrid worker')
param vmName string

@description('The resource group containing the existing VM')
param vmResourceGroup string

@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the first runbook')
param runbook1Name string = 'HelloWorldRunbook'

@description('The name of the second runbook')
param runbook2Name string = 'DiskSpaceRunbook'

// Load PowerShell content from files
var runbook1Content = loadTextContent('runbooks/HelloWorldRunbook.ps1')
var runbook2Content = loadTextContent('runbooks/DiskSpaceRunbook.ps1')

// Variables
var automationAccountId = resourceId('Microsoft.Automation/automationAccounts', automationAccountName)
var hybridWorkerGroupId = '${automationAccountId}/hybridRunbookWorkerGroups/${hybridWorkerGroupName}'

// Get the existing VM
resource existingVM 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: vmName
  scope: resourceGroup(vmResourceGroup)
}

// Automation Account
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

// Hybrid Worker Group
resource hybridWorkerGroup 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups@2023-11-01' = {
  name: '${automationAccountName}/${hybridWorkerGroupName}'
  properties: {
    credential: {
      name: 'DefaultRunAsAccount'
    }
  }
}

// Hybrid Worker (VM registration)
resource hybridWorker 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups/hybridRunbookWorkers@2023-11-01' = {
  name: '${automationAccountName}/${hybridWorkerGroupName}/${vmName}'
  properties: {
    ip: existingVM.properties.networkProfile.networkInterfaces[0].id
    registeredDateTime: utcNow()
  }
}

// First Runbook
resource runbook1 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  name: '${automationAccountName}/${runbook1Name}'
  properties: {
    runbookType: 'PowerShell'
    logVerbose: true
    logProgress: true
    description: 'Hello World PowerShell runbook with system information'
  }
}

// Second Runbook
resource runbook2 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  name: '${automationAccountName}/${runbook2Name}'
  properties: {
    runbookType: 'PowerShell'
    logVerbose: true
    logProgress: true
    description: 'Disk space monitoring PowerShell runbook'
  }
}

// Runbook Content for Runbook1
resource runbook1Content 'Microsoft.Automation/automationAccounts/runbooks/content@2023-11-01' = {
  name: '${automationAccountName}/${runbook1Name}'
  properties: {
    content: runbook1Content
  }
}

// Runbook Content for Runbook2
resource runbook2Content 'Microsoft.Automation/automationAccounts/runbooks/content@2023-11-01' = {
  name: '${automationAccountName}/${runbook2Name}'
  properties: {
    content: runbook2Content
  }
}

// Publish Runbook1
resource runbook1Publish 'Microsoft.Automation/automationAccounts/runbooks/publish@2023-11-01' = {
  name: '${automationAccountName}/${runbook1Name}'
  properties: {
    isLogProgressEnabled: true
    isLogVerboseEnabled: true
  }
}

// Publish Runbook2
resource runbook2Publish 'Microsoft.Automation/automationAccounts/runbooks/publish@2023-11-01' = {
  name: '${automationAccountName}/${runbook2Name}'
  properties: {
    isLogProgressEnabled: true
    isLogVerboseEnabled: true
  }
}

// Outputs
output automationAccountId string = automationAccount.id
output automationAccountName string = automationAccount.name
output hybridWorkerGroupId string = hybridWorkerGroup.id
output hybridWorkerGroupName string = hybridWorkerGroup.name
output runbook1Id string = runbook1.id
output runbook2Id string = runbook2.id
output vmId string = existingVM.id