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
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$BicepFile = "main.bicep"
)

Write-Host "Starting deployment of Azure Automation Account with Hybrid Worker Group..." -ForegroundColor Green

# Check if Azure CLI is installed and logged in
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Yellow
} catch {
    Write-Error "Azure CLI is not installed or not accessible. Please install Azure CLI first."
    exit 1
}

# Check if logged in to Azure
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Yellow
    Write-Host "Subscription: $($account.name)" -ForegroundColor Yellow
} catch {
    Write-Error "Not logged in to Azure. Please run 'az login' first."
    exit 1
}

# Check if Bicep is installed
try {
    $bicepVersion = bicep --version
    Write-Host "Bicep version: $bicepVersion" -ForegroundColor Yellow
} catch {
    Write-Error "Bicep is not installed. Please install Bicep first: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install"
    exit 1
}

# Create resource group if it doesn't exist
Write-Host "Checking if resource group '$ResourceGroupName' exists..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Creating resource group '$ResourceGroupName' in location '$Location'..." -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location
} else {
    Write-Host "Resource group '$ResourceGroupName' already exists." -ForegroundColor Green
}

# Validate the Bicep template
Write-Host "Validating Bicep template..." -ForegroundColor Yellow
bicep build $BicepFile

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep template validation failed."
    exit 1
}

# Deploy the template
Write-Host "Deploying Bicep template..." -ForegroundColor Yellow
$deploymentName = "AutomationAccountDeployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $BicepFile `
    --name $deploymentName `
    --parameters `
        automationAccountName=$AutomationAccountName `
        vmName=$VMName `
        vmResourceGroup=$VMResourceGroup `
        location=$Location

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Deployment name: $deploymentName" -ForegroundColor Yellow
    
    # Get deployment outputs
    Write-Host "`nDeployment outputs:" -ForegroundColor Yellow
    az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query properties.outputs `
        --output table
} else {
    Write-Error "Deployment failed."
    exit 1
}

Write-Host "`nNext steps:" -ForegroundColor Green
Write-Host "1. Install the Hybrid Runbook Worker on your VM: https://docs.microsoft.com/en-us/azure/automation/automation-hybrid-runbook-worker-install" -ForegroundColor White
Write-Host "2. Register the VM with the hybrid worker group" -ForegroundColor White
Write-Host "3. Test your runbooks in the Azure Portal" -ForegroundColor White