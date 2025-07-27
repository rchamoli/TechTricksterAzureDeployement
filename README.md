# Azure Automation Account with Hybrid Worker Group - Bicep Template

This repository contains Bicep templates to deploy an Azure Automation Account with a hybrid worker group and PowerShell runbooks.

## Overview

The solution creates:
1. **Azure Automation Account** - The main automation service
2. **Hybrid Worker Group** - A group to manage hybrid workers
3. **Hybrid Worker Registration** - Registers an existing VM as a hybrid worker
4. **Two PowerShell Runbooks** - Sample runbooks that are uploaded and published

## Prerequisites

- Azure CLI installed and configured
- Bicep CLI installed
- An existing Azure VM that will be used as a hybrid worker
- Appropriate permissions to create resources in Azure

## Files Structure

```
├── main.bicep                    # Main Bicep template with inline PowerShell content
├── main-with-files.bicep         # Alternative template that loads PowerShell from files
├── parameters.json               # Sample parameters file
├── deploy.ps1                    # PowerShell deployment script
├── runbooks/
│   ├── HelloWorldRunbook.ps1     # First PowerShell runbook
│   └── DiskSpaceRunbook.ps1      # Second PowerShell runbook
└── README.md                     # This file
```

## Runbooks Included

### 1. HelloWorldRunbook.ps1
A simple PowerShell runbook that:
- Accepts a name parameter (defaults to "World")
- Displays greeting message
- Shows current time and computer name
- Provides system information (OS version, PowerShell version, memory)

### 2. DiskSpaceRunbook.ps1
A disk monitoring PowerShell runbook that:
- Accepts a path parameter (defaults to "C:\")
- Retrieves disk space information
- Shows total, free, and used space
- Calculates percentage used
- Provides warnings for high disk usage

## Deployment Options

### Option 1: Using the PowerShell Deployment Script (Recommended)

```powershell
# Navigate to the project directory
cd /path/to/your/project

# Run the deployment script
.\deploy.ps1 -ResourceGroupName "myResourceGroup" `
             -AutomationAccountName "myAutomationAccount" `
             -VMName "myExistingVM" `
             -VMResourceGroup "myVMResourceGroup" `
             -Location "East US"
```

### Option 2: Using Azure CLI Directly

```bash
# Deploy using the main template
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main.bicep \
  --parameters \
    automationAccountName=myAutomationAccount \
    vmName=myExistingVM \
    vmResourceGroup=myVMResourceGroup \
    location=East US

# Or deploy using the template with external files
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main-with-files.bicep \
  --parameters \
    automationAccountName=myAutomationAccount \
    vmName=myExistingVM \
    vmResourceGroup=myVMResourceGroup \
    location=East US
```

### Option 3: Using Parameters File

```bash
# Edit parameters.json with your values, then deploy
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main.bicep \
  --parameters @parameters.json
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `automationAccountName` | string | Yes | Name of the Automation Account |
| `hybridWorkerGroupName` | string | No | Name of the Hybrid Worker Group (default: DefaultWorkerGroup) |
| `vmName` | string | Yes | Name of the existing VM to register as hybrid worker |
| `vmResourceGroup` | string | Yes | Resource group containing the existing VM |
| `location` | string | No | Location for resources (default: resource group location) |
| `runbook1Name` | string | No | Name of the first runbook (default: HelloWorldRunbook) |
| `runbook2Name` | string | No | Name of the second runbook (default: DiskSpaceRunbook) |

## Post-Deployment Steps

After successful deployment, you need to complete the hybrid worker setup:

### 1. Install Hybrid Runbook Worker on VM

On your target VM, install the Hybrid Runbook Worker:

```powershell
# Download and install the Hybrid Runbook Worker
# Follow the official Microsoft documentation:
# https://docs.microsoft.com/en-us/azure/automation/automation-hybrid-runbook-worker-install
```

### 2. Register VM with Hybrid Worker Group

The Bicep template creates the hybrid worker group and attempts to register the VM, but you may need to complete the registration manually through the Azure Portal or PowerShell.

### 3. Test Runbooks

1. Go to the Azure Portal
2. Navigate to your Automation Account
3. Go to "Runbooks" section
4. Test the published runbooks

## Important Notes

1. **VM Requirements**: The target VM must be running Windows and have PowerShell 5.1 or later
2. **Network Access**: The VM must have internet access to communicate with Azure Automation
3. **Permissions**: The VM needs appropriate permissions to register as a hybrid worker
4. **Runbook Execution**: Runbooks will execute on the hybrid worker VM, not in the Azure cloud

## Troubleshooting

### Common Issues

1. **VM Registration Fails**
   - Ensure the VM has internet connectivity
   - Check that the Hybrid Runbook Worker is properly installed
   - Verify the VM has the correct permissions

2. **Runbook Execution Fails**
   - Check the runbook logs in the Azure Portal
   - Ensure the hybrid worker is online and healthy
   - Verify PowerShell execution policy on the VM

3. **Deployment Fails**
   - Check Azure CLI and Bicep versions
   - Verify you have appropriate permissions
   - Check the deployment logs for specific error messages

## Security Considerations

- The Automation Account uses Basic SKU by default
- Consider using User-Assigned Managed Identity for enhanced security
- Review and adjust the runbook content based on your security requirements
- Ensure the hybrid worker VM follows your organization's security policies

## Support

For issues related to:
- **Azure Automation**: [Azure Automation Documentation](https://docs.microsoft.com/en-us/azure/automation/)
- **Hybrid Runbook Workers**: [Hybrid Worker Documentation](https://docs.microsoft.com/en-us/azure/automation/automation-hybrid-runbook-worker)
- **Bicep**: [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

## License

This project is provided as-is for educational and demonstration purposes.