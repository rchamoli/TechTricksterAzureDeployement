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
param runbook1Name string = 'Runbook1'

@description('The name of the second runbook')
param runbook2Name string = 'Runbook2'

@description('The content of the first PowerShell runbook')
param runbook1Content string = @'
param([string]$Name = "World")
Write-Output "Hello, $Name!"
Write-Output "Current time: $(Get-Date)"
Write-Output "Running on: $env:COMPUTERNAME"
'@

@description('The content of the second PowerShell runbook')
param runbook2Content string = @'
param([string]$Path = "C:\")
Write-Output "Getting disk space information for: $Path"
$diskInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq $Path.Substring(0,2)}
if ($diskInfo) {
    Write-Output "Drive: $($diskInfo.DeviceID)"
    Write-Output "Total Space: $([math]::Round($diskInfo.Size/1GB, 2)) GB"
    Write-Output "Free Space: $([math]::Round($diskInfo.FreeSpace/1GB, 2)) GB"
    Write-Output "Used Space: $([math]::Round(($diskInfo.Size - $diskInfo.FreeSpace)/1GB, 2)) GB"
} else {
    Write-Output "Could not retrieve disk information for $Path"
}
'@

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
    description: 'Sample PowerShell runbook for demonstration'
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