# Azure Automation Account with Hybrid Worker Group - Bicep Template

This repository contains a comprehensive Bicep template for deploying an Azure Automation Account with Hybrid Worker Group functionality, including the ability to add an existing VM as a hybrid worker and deploy PowerShell runbooks.

## 🏗️ Architecture Overview

The template creates the following resources:

- **Azure Automation Account** with System Assigned Managed Identity
- **Log Analytics Workspace** linked to the Automation Account
- **Hybrid Worker Group** for running runbooks on-premises or in other clouds
- **Hybrid Worker Extension** installed on an existing VM
- **Two PowerShell Runbooks** with comprehensive functionality
- **Role Assignments** for proper permissions

## 📋 Prerequisites

Before deploying this template, ensure you have:

1. **Azure CLI** or **Azure PowerShell** installed
2. **Bicep CLI** installed (for direct Bicep deployment)
3. An **existing Windows VM** in Azure that will serve as the hybrid worker
4. **Appropriate Azure permissions** to:
   - Create resources in the target resource group
   - Assign roles at the resource group level
   - Install extensions on VMs

## 🚀 Quick Start

### Option 1: Using the PowerShell Deployment Script (Recommended)

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd azure-automation-bicep
   ```

2. **Connect to Azure**:
   ```powershell
   Connect-AzAccount
   Set-AzContext -SubscriptionId "your-subscription-id"
   ```

3. **Run the deployment script**:
   ```powershell
   .\deploy-automation.ps1 -ResourceGroupName "rg-automation-demo" `
                           -ExistingVmResourceId "/subscriptions/your-sub-id/resourceGroups/rg-vm/providers/Microsoft.Compute/virtualMachines/vm-name" `
                           -ExistingVmResourceGroupName "rg-vm" `
                           -ExistingVmName "vm-name" `
                           -Location "East US"
   ```

### Option 2: Using Azure CLI with Bicep

1. **Update the parameter file**:
   Edit `main.bicepparam` with your specific values:
   ```bicep
   param existingVmResourceId = '/subscriptions/{your-subscription-id}/resourceGroups/{vm-resource-group}/providers/Microsoft.Compute/virtualMachines/{vm-name}'
   param existingVmResourceGroupName = '{vm-resource-group-name}'
   param existingVmName = '{vm-name}'
   ```

2. **Deploy the template**:
   ```bash
   az group create --name rg-automation-demo --location "East US"
   az deployment group create --resource-group rg-automation-demo --template-file main.bicep --parameters main.bicepparam
   ```

3. **Upload and publish runbooks manually** (see Post-Deployment Steps)

### Option 3: Using Azure PowerShell

```powershell
# Create resource group
New-AzResourceGroup -Name "rg-automation-demo" -Location "East US"

# Deploy template
New-AzResourceGroupDeployment -ResourceGroupName "rg-automation-demo" `
                              -TemplateFile ".\main.bicep" `
                              -TemplateParameterFile ".\main.bicepparam"
```

## 📁 Repository Structure

```
├── main.bicep                 # Main Bicep template
├── main.bicepparam           # Parameter file for easy deployment
├── deploy-automation.ps1     # PowerShell deployment script
├── scripts/
│   ├── Get-SystemInfo.ps1    # Runbook 1: System information collection
│   └── Restart-Service.ps1   # Runbook 2: Service management
└── README.md                 # This file
```

## 🔧 Template Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | string | No | Azure region for deployment (default: resource group location) |
| `automationAccountName` | string | No | Name of the Automation Account (default: auto-generated) |
| `hybridWorkerGroupName` | string | No | Name of the hybrid worker group (default: 'HybridWorkerGroup') |
| `existingVmResourceId` | string | **Yes** | Full resource ID of the existing VM |
| `existingVmResourceGroupName` | string | **Yes** | Resource group name where the VM is located |
| `existingVmName` | string | **Yes** | Name of the existing VM |
| `runbook1Name` | string | No | Name for the first runbook (default: 'Get-SystemInfo') |
| `runbook2Name` | string | No | Name for the second runbook (default: 'Restart-Service') |
| `tags` | object | No | Tags to apply to all resources |

## 📖 Runbook Details

### 1. Get-SystemInfo Runbook

This runbook collects comprehensive system information including:
- Computer and OS details
- Processor information
- Disk usage statistics
- Network configuration
- Top memory-consuming processes
- System uptime
- Windows update status
- Recent system errors
- Azure VM metadata (if applicable)

**Usage**: Run without parameters to get full system report.

### 2. Restart-Service Runbook

This runbook provides service management capabilities:
- Start, stop, restart, or check status of Windows services
- Dependency analysis
- Timeout configuration
- Event logging
- Comprehensive error handling

**Parameters**:
- `ServiceName` (Required): Name of the Windows service
- `Action` (Optional): Action to perform - 'Start', 'Stop', 'Restart', 'Status' (default: 'Restart')
- `TimeoutSeconds` (Optional): Operation timeout in seconds (default: 60)
- `WaitForStatus` (Optional): Wait for status change completion (default: true)

**Example Usage**:
```powershell
# Check service status
Start-AzAutomationRunbook -AutomationAccountName "aa-demo" -Name "Restart-Service" -Parameters @{ServiceName="Spooler"; Action="Status"}

# Restart a service
Start-AzAutomationRunbook -AutomationAccountName "aa-demo" -Name "Restart-Service" -Parameters @{ServiceName="Spooler"; Action="Restart"}
```

## 🔐 Security Features

- **Managed Identity**: Automation Account uses system-assigned managed identity
- **Role-Based Access**: Minimal required permissions assigned
- **Secure Communication**: All communication encrypted
- **Extension-Based**: Uses modern VM extension for hybrid worker registration

## 📋 Post-Deployment Steps

After deployment, you may need to:

1. **Verify Hybrid Worker Registration**:
   - Go to Azure Portal → Automation Account → Hybrid worker groups
   - Confirm your VM appears in the group

2. **Test Runbooks**:
   ```powershell
   # Test system info runbook
   Start-AzAutomationRunbook -AutomationAccountName "aa-demo" -Name "Get-SystemInfo" -RunOn "HybridWorkerGroup-Demo"
   
   # Test service management runbook
   Start-AzAutomationRunbook -AutomationAccountName "aa-demo" -Name "Restart-Service" -Parameters @{ServiceName="Spooler"; Action="Status"} -RunOn "HybridWorkerGroup-Demo"
   ```

3. **Create Schedules** (Optional):
   - Set up recurring schedules for system monitoring
   - Configure alert-based automation

## 🔍 Troubleshooting

### Common Issues

1. **Hybrid Worker Extension Installation Fails**:
   - Ensure the VM has outbound internet connectivity
   - Check if the VM is running and accessible
   - Verify the VM is Windows-based

2. **Runbook Execution Fails**:
   - Check if the hybrid worker is online
   - Verify PowerShell execution policy on the target VM
   - Review runbook logs in the Azure portal

3. **Permission Errors**:
   - Ensure the deployment account has Contributor access
   - Verify the Automation Account's managed identity has required permissions

### Useful Commands

```powershell
# Check hybrid worker status
Get-AzAutomationHybridWorkerGroup -ResourceGroupName "rg-demo" -AutomationAccountName "aa-demo"

# View runbook job status
Get-AzAutomationJob -ResourceGroupName "rg-demo" -AutomationAccountName "aa-demo"

# Check VM extension status
Get-AzVMExtension -ResourceGroupName "rg-vm" -VMName "vm-name"
```

## 🧹 Cleanup

To remove all resources created by this template:

```powershell
# Remove the resource group (includes all resources)
Remove-AzResourceGroup -Name "rg-automation-demo" -Force

# Or remove individual resources if needed
Remove-AzAutomationAccount -ResourceGroupName "rg-automation-demo" -Name "aa-demo"
```

## 📚 Additional Resources

- [Azure Automation Documentation](https://docs.microsoft.com/en-us/azure/automation/)
- [Hybrid Runbook Worker Overview](https://docs.microsoft.com/en-us/azure/automation/automation-hybrid-runbook-worker)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

This template is provided as-is for educational and demonstration purposes. Please review and test thoroughly before using in production environments.