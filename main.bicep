@description('The name of the Automation Account')
param automationAccountName string

@description('The name of the Hybrid Worker Group')
param hybridWorkerGroupName string = 'DefaultWorkerGroup'

@description('The name of the existing VM to add as a hybrid worker')
param vmName string

@description('The resource group containing the existing VM')
param vmResourceGroup string

@description('The location for resources')
param location string = resourceGroup().location

@description('The name of the first runbook')
param runbook1Name string = 'Runbook1'

@description('The name of the second runbook')
param runbook2Name string = 'Runbook2'

@description('The content of the first PowerShell runbook')
param runbook1Content string = @'
param([string]$ComputerName = "localhost")

Write-Output "Starting runbook execution on $ComputerName"
Write-Output "Current time: $(Get-Date)"

# Get system information
$systemInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory
Write-Output "System Information:"
$systemInfo | Format-List

# Get running services
$services = Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object Name, Status, DisplayName
Write-Output "Running Services Count: $($services.Count)"

Write-Output "Runbook execution completed successfully"
'@

@description('The content of the second PowerShell runbook')
param runbook2Content string = @'
param([string]$ResourceGroupName)

Write-Output "Starting resource inventory runbook"
Write-Output "Current time: $(Get-Date)"

# Get all resources in the specified resource group
$resources = Get-AzResource -ResourceGroupName $ResourceGroupName

Write-Output "Resources in Resource Group '$ResourceGroupName':"
foreach ($resource in $resources) {
    Write-Output "  - $($resource.Name) ($($resource.Type))"
}

Write-Output "Total resources found: $($resources.Count)"

# Get VM information
$vms = Get-AzVM -ResourceGroupName $ResourceGroupName
Write-Output "Virtual Machines:"
foreach ($vm in $vms) {
    Write-Output "  - $($vm.Name) (Status: $($vm.PowerState))"
}

Write-Output "Resource inventory completed successfully"
'@

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
  name: '${automationAccount.name}/${hybridWorkerGroupName}'
  properties: {
    credential: {
      name: 'DefaultRunAsCredential'
    }
  }
}

// Hybrid Worker (VM registration)
resource hybridWorker 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups/hybridRunbookWorkers@2023-11-01' = {
  name: '${automationAccount.name}/${hybridWorkerGroupName}/${vmName}'
  properties: {
    vmResourceId: existingVM.id
    workerType: 'HybridV1'
  }
}

// First Runbook
resource runbook1 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  name: '${automationAccount.name}/${runbook1Name}'
  properties: {
    runbookType: 'PowerShell'
    logVerbose: true
    logProgress: true
    description: 'Sample PowerShell runbook for system information'
  }
}

// Second Runbook
resource runbook2 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  name: '${automationAccount.name}/${runbook2Name}'
  properties: {
    runbookType: 'PowerShell'
    logVerbose: true
    logProgress: true
    description: 'Sample PowerShell runbook for resource inventory'
  }
}

// Upload content for first runbook
resource runbook1Content 'Microsoft.Automation/automationAccounts/runbooks/content@2023-11-01' = {
  name: '${automationAccount.name}/${runbook1Name}'
  properties: {
    content: runbook1Content
  }
}

// Upload content for second runbook
resource runbook2Content 'Microsoft.Automation/automationAccounts/runbooks/content@2023-11-01' = {
  name: '${automationAccount.name}/${runbook2Name}'
  properties: {
    content: runbook2Content
  }
}

// Publish first runbook
resource runbook1Publish 'Microsoft.Automation/automationAccounts/runbooks/publish@2023-11-01' = {
  name: '${automationAccount.name}/${runbook1Name}'
  properties: {
    isLogProgressEnabled: true
    isLogVerboseEnabled: true
  }
}

// Publish second runbook
resource runbook2Publish 'Microsoft.Automation/automationAccounts/runbooks/publish@2023-11-01' = {
  name: '${automationAccount.name}/${runbook2Name}'
  properties: {
    isLogProgressEnabled: true
    isLogVerboseEnabled: true
  }
}

// Outputs
output automationAccountName string = automationAccount.name
output automationAccountId string = automationAccount.id
output hybridWorkerGroupName string = hybridWorkerGroup.name
output runbook1Name string = runbook1.name
output runbook2Name string = runbook2.name
output vmResourceId string = existingVM.id