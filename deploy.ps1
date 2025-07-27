param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AutomationAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$HybridWorkerGroupName = "DefaultWorkerGroup",
    
    [Parameter(Mandatory=$false)]
    [string]$Runbook1Name = "SystemInfoRunbook",
    
    [Parameter(Mandatory=$false)]
    [string]$Runbook2Name = "ResourceInventoryRunbook"
)

Write-Host "Starting deployment of Automation Account with Hybrid Worker Group..." -ForegroundColor Green

# Check if resource group exists, create if not
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

# Check if the VM exists
$vm = Get-AzVM -ResourceGroupName $VMResourceGroup -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Error "VM '$VMName' not found in resource group '$VMResourceGroup'"
    exit 1
}

# Deploy the Bicep template
Write-Host "Deploying Bicep template..." -ForegroundColor Yellow

$deploymentParams = @{
    ResourceGroupName = $ResourceGroupName
    TemplateFile = "main.bicep"
    TemplateParameterObject = @{
        automationAccountName = $AutomationAccountName
        hybridWorkerGroupName = $HybridWorkerGroupName
        vmName = $VMName
        vmResourceGroup = $VMResourceGroup
        location = $Location
        runbook1Name = $Runbook1Name
        runbook2Name = $Runbook2Name
    }
    Verbose = $true
}

$deployment = New-AzResourceGroupDeployment @deploymentParams

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Automation Account: $($deployment.Outputs.automationAccountName.Value)" -ForegroundColor Cyan
Write-Host "Hybrid Worker Group: $($deployment.Outputs.hybridWorkerGroupName.Value)" -ForegroundColor Cyan
Write-Host "Runbook 1: $($deployment.Outputs.runbook1Name.Value)" -ForegroundColor Cyan
Write-Host "Runbook 2: $($deployment.Outputs.runbook2Name.Value)" -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Install the Hybrid Runbook Worker on the VM: $VMName" -ForegroundColor White
Write-Host "2. Configure the worker to connect to the Automation Account" -ForegroundColor White
Write-Host "3. Test the runbooks in the Azure Portal" -ForegroundColor White