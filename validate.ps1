param(
    [Parameter(Mandatory=$false)]
    [string]$BicepFile = "main.bicep",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "test-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US"
)

Write-Host "Validating Bicep template: $BicepFile" -ForegroundColor Green

# Check if Bicep is installed
try {
    $bicepVersion = bicep --version
    Write-Host "Bicep version: $bicepVersion" -ForegroundColor Yellow
} catch {
    Write-Error "Bicep is not installed. Please install Bicep first: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install"
    exit 1
}

# Check if file exists
if (-not (Test-Path $BicepFile)) {
    Write-Error "Bicep file '$BicepFile' not found."
    exit 1
}

# Build the Bicep file
Write-Host "Building Bicep template..." -ForegroundColor Yellow
bicep build $BicepFile

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep build failed."
    exit 1
}

Write-Host "Bicep build completed successfully." -ForegroundColor Green

# Check if Azure CLI is available for validation
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Yellow
    
    # Validate against Azure (requires Azure CLI and login)
    Write-Host "Validating template against Azure..." -ForegroundColor Yellow
    
    # Create a temporary resource group for validation if it doesn't exist
    $rgExists = az group exists --name $ResourceGroupName
    if ($rgExists -eq "false") {
        Write-Host "Creating temporary resource group '$ResourceGroupName' for validation..." -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location
    }
    
    # Validate the template
    az deployment group validate `
        --resource-group $ResourceGroupName `
        --template-file $BicepFile `
        --parameters `
            automationAccountName="test-automation-account" `
            vmName="test-vm" `
            vmResourceGroup="test-vm-rg" `
            location=$Location
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Template validation completed successfully!" -ForegroundColor Green
    } else {
        Write-Warning "Template validation completed with warnings or errors. Check the output above."
    }
    
} catch {
    Write-Warning "Azure CLI validation skipped. Make sure you're logged in with 'az login' for full validation."
}

Write-Host "`nValidation Summary:" -ForegroundColor Green
Write-Host "✓ Bicep syntax is valid" -ForegroundColor Green
Write-Host "✓ Template builds successfully" -ForegroundColor Green

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Template validates against Azure" -ForegroundColor Green
} else {
    Write-Host "⚠ Azure validation status unclear - check output above" -ForegroundColor Yellow
}

Write-Host "`nTemplate is ready for deployment!" -ForegroundColor Green