using './main.bicep'

// ================================================================================================
// AZURE AUTOMATION ACCOUNT DEPLOYMENT PARAMETERS
// ================================================================================================
// NOTE: Update these parameters according to your environment before deployment
// ================================================================================================

// Basic Configuration
param location = 'East US'
param automationAccountName = 'aa-hybrid-demo'
param hybridWorkerGroupName = 'HybridWorkerGroup-Demo'

// Existing VM Configuration
// IMPORTANT: Update these values to match your existing VM
param existingVmResourceId = '/subscriptions/{subscription-id}/resourceGroups/{vm-resource-group}/providers/Microsoft.Compute/virtualMachines/{vm-name}'
param existingVmResourceGroupName = '{vm-resource-group-name}'
param existingVmName = '{vm-name}'

// Runbook Configuration
param runbook1Name = 'Get-SystemInfo'
param runbook2Name = 'Restart-Service'

// Tags
param tags = {
  Environment: 'Development'
  Project: 'AutomationWithHybridWorker'
  Owner: 'IT Operations'
  CostCenter: '12345'
  CreatedBy: 'Azure Automation Bicep Template'
}