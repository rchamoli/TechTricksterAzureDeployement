# Azure Automation Account with Hybrid Worker Group

This Bicep template creates an Azure Automation Account with a hybrid worker group and deploys two PowerShell runbooks.

## What this template creates:

1. **Automation Account** - Basic SKU automation account
2. **Hybrid Worker Group** - A worker group for hybrid runbook workers
3. **Hybrid Worker Registration** - Registers an existing VM as a hybrid worker
4. **Two PowerShell Runbooks**:
   - **SystemInfoRunbook**: Collects system information from the hybrid worker
   - **ResourceInventoryRunbook**: Lists Azure resources in a specified resource group

## Prerequisites

- Azure CLI or Azure PowerShell module installed
- An existing Azure VM that will be used as a hybrid worker
- Appropriate permissions to create resources in Azure

## Files included:

- `main.bicep` - Main Bicep template
- `parameters.json` - Sample parameters file
- `deploy.ps1` - PowerShell deployment script
- `runbooks/SystemInfoRunbook.ps1` - First runbook content
- `runbooks/ResourceInventoryRunbook.ps1` - Second runbook content

## Deployment Options

### Option 1: Using PowerShell Script (Recommended)

```powershell
# Deploy using the PowerShell script
.\deploy.ps1 -ResourceGroupName "myResourceGroup" `
             -AutomationAccountName "myAutomationAccount" `
             -VMName "myExistingVM" `
             -VMResourceGroup "myVMResourceGroup" `
             -Location "eastus"
```

### Option 2: Using Azure CLI

```bash
# Deploy using Azure CLI
az deployment group create \
  --resource-group "myResourceGroup" \
  --template-file "main.bicep" \
  --parameters automationAccountName="myAutomationAccount" \
                vmName="myExistingVM" \
                vmResourceGroup="myVMResourceGroup" \
                location="eastus"
```

### Option 3: Using Parameters File

```bash
# Deploy using parameters file
az deployment group create \
  --resource-group "myResourceGroup" \
  --template-file "main.bicep" \
  --parameters "@parameters.json"
```

## Parameters

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `automationAccountName` | Yes | Name of the Automation Account | - |
| `hybridWorkerGroupName` | No | Name of the Hybrid Worker Group | DefaultWorkerGroup |
| `vmName` | Yes | Name of the existing VM to add as hybrid worker | - |
| `vmResourceGroup` | Yes | Resource group containing the existing VM | - |
| `location` | No | Location for resources | Resource group location |
| `runbook1Name` | No | Name of the first runbook | Runbook1 |
| `runbook2Name` | No | Name of the second runbook | Runbook2 |

## Post-Deployment Steps

### 1. Install Hybrid Runbook Worker on the VM

After deployment, you need to install the Hybrid Runbook Worker on your VM:

1. Go to your Automation Account in the Azure Portal
2. Navigate to **Hybrid worker groups**
3. Select your worker group
4. Click **Add a hybrid worker**
5. Follow the installation instructions for your VM

### 2. Configure Run As Account (if needed)

For runbooks that need to access Azure resources:

1. In your Automation Account, go to **Run as accounts**
2. Create a Run As account if it doesn't exist
3. This will be used by runbooks to authenticate with Azure

### 3. Test the Runbooks

1. Go to **Runbooks** in your Automation Account
2. Select one of the created runbooks
3. Click **Start** to test execution
4. Monitor the job output

## Runbook Details

### SystemInfoRunbook
- **Purpose**: Collects system information from the hybrid worker
- **Parameters**: `ComputerName` (optional, defaults to "localhost")
- **Output**: System information, running services, disk usage, network adapters

### ResourceInventoryRunbook
- **Purpose**: Lists Azure resources in a specified resource group
- **Parameters**: `ResourceGroupName` (required)
- **Output**: List of resources, VMs, storage accounts, network interfaces, public IPs

## Troubleshooting

### Common Issues:

1. **VM not found**: Ensure the VM name and resource group are correct
2. **Permission errors**: Verify you have appropriate permissions to create resources
3. **Hybrid worker not connecting**: Check network connectivity and firewall settings
4. **Runbook execution fails**: Verify the Run As account is configured properly

### Logs and Monitoring:

- Check **Jobs** in the Automation Account for runbook execution logs
- Monitor **Hybrid worker groups** for worker status
- Use **Log Analytics** for detailed monitoring (if configured)

## Security Considerations

- Use Run As accounts for Azure authentication
- Implement proper network security groups
- Consider using private endpoints for enhanced security
- Regularly rotate automation account keys

## Cost Optimization

- The Basic SKU is used by default (free tier)
- Monitor usage to avoid unexpected charges
- Consider using Azure Policy to enforce cost controls

## Support

For issues with this template or Azure Automation, refer to:
- [Azure Automation Documentation](https://docs.microsoft.com/en-us/azure/automation/)
- [Hybrid Runbook Worker Documentation](https://docs.microsoft.com/en-us/azure/automation/automation-hybrid-runbook-worker)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)