# ================================================================================================
# AZURE AUTOMATION ACCOUNT DEPLOYMENT SCRIPT
# ================================================================================================
# Description: Deploys Azure Automation Account with Hybrid Worker Group and publishes runbooks
# Author: Azure Automation Team
# Version: 1.0
# ================================================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ExistingVmResourceId,
    
    [Parameter(Mandatory=$true)]
    [string]$ExistingVmResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ExistingVmName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$AutomationAccountName = "aa-hybrid-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$HybridWorkerGroupName = "HybridWorkerGroup-Demo",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

# Set strict mode and error action
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Azure Automation Account Deployment Script" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    
    # Check if user is logged in to Azure
    Write-Host "`n[STEP 1] Checking Azure login status..." -ForegroundColor Yellow
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Not logged in to Azure. Please run 'Connect-AzAccount' first." -ForegroundColor Red
        return
    }
    
    Write-Host "Logged in as: $($context.Account.Id)" -ForegroundColor Green
    Write-Host "Current subscription: $($context.Subscription.Name)" -ForegroundColor Green
    
    # Set subscription if provided
    if ($SubscriptionId) {
        Write-Host "Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
        Set-AzContext -SubscriptionId $SubscriptionId
    }
    
    # Check if resource group exists
    Write-Host "`n[STEP 2] Checking resource group..." -ForegroundColor Yellow
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) {
        Write-Host "Resource group '$ResourceGroupName' not found. Creating it..." -ForegroundColor Yellow
        $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Host "Resource group created successfully." -ForegroundColor Green
    } else {
        Write-Host "Resource group '$ResourceGroupName' already exists." -ForegroundColor Green
    }
    
    # Validate existing VM
    Write-Host "`n[STEP 3] Validating existing VM..." -ForegroundColor Yellow
    try {
        $vm = Get-AzVM -ResourceGroupName $ExistingVmResourceGroupName -Name $ExistingVmName -ErrorAction Stop
        Write-Host "VM '$ExistingVmName' found and validated." -ForegroundColor Green
        Write-Host "VM Location: $($vm.Location)" -ForegroundColor Green
        Write-Host "VM Size: $($vm.HardwareProfile.VmSize)" -ForegroundColor Green
    } catch {
        Write-Host "Error: Could not find VM '$ExistingVmName' in resource group '$ExistingVmResourceGroupName'." -ForegroundColor Red
        throw
    }
    
    # Deploy Bicep template
    Write-Host "`n[STEP 4] Deploying Bicep template..." -ForegroundColor Yellow
    $deploymentName = "AutomationAccount-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    $templateParameters = @{
        'location' = $Location
        'automationAccountName' = $AutomationAccountName
        'hybridWorkerGroupName' = $HybridWorkerGroupName
        'existingVmResourceId' = $ExistingVmResourceId
        'existingVmResourceGroupName' = $ExistingVmResourceGroupName
        'existingVmName' = $ExistingVmName
    }
    
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile "./main.bicep" `
        -TemplateParameterObject $templateParameters `
        -Name $deploymentName `
        -Verbose
    
    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "Bicep template deployed successfully!" -ForegroundColor Green
    } else {
        throw "Bicep template deployment failed with state: $($deployment.ProvisioningState)"
    }
    
    # Wait for automation account to be ready
    Write-Host "`n[STEP 5] Waiting for Automation Account to be ready..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 10
        $automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue
        Write-Host "Waiting for Automation Account..." -ForegroundColor Yellow
    } while (-not $automationAccount)
    
    Write-Host "Automation Account is ready!" -ForegroundColor Green
    
    # Upload and publish runbook 1: Get-SystemInfo
    Write-Host "`n[STEP 6] Uploading and publishing Get-SystemInfo runbook..." -ForegroundColor Yellow
    
    # Check if script file exists
    $script1Path = "./scripts/Get-SystemInfo.ps1"
    if (-not (Test-Path $script1Path)) {
        throw "PowerShell script not found: $script1Path"
    }
    
    # Import runbook content
    Import-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name "Get-SystemInfo" `
        -Type PowerShell `
        -Path $script1Path `
        -Force
    
    # Publish runbook
    Publish-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name "Get-SystemInfo"
    
    Write-Host "Get-SystemInfo runbook uploaded and published successfully!" -ForegroundColor Green
    
    # Upload and publish runbook 2: Restart-Service
    Write-Host "`n[STEP 7] Uploading and publishing Restart-Service runbook..." -ForegroundColor Yellow
    
    # Check if script file exists
    $script2Path = "./scripts/Restart-Service.ps1"
    if (-not (Test-Path $script2Path)) {
        throw "PowerShell script not found: $script2Path"
    }
    
    # Import runbook content
    Import-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name "Restart-Service" `
        -Type PowerShell `
        -Path $script2Path `
        -Force
    
    # Publish runbook
    Publish-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name "Restart-Service"
    
    Write-Host "Restart-Service runbook uploaded and published successfully!" -ForegroundColor Green
    
    # Verify hybrid worker registration
    Write-Host "`n[STEP 8] Verifying hybrid worker registration..." -ForegroundColor Yellow
    $maxAttempts = 30
    $attempt = 0
    $hybridWorkerRegistered = $false
    
    do {
        $attempt++
        Start-Sleep -Seconds 10
        
        try {
            $hybridWorkers = Get-AzAutomationHybridWorkerGroup -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
            $targetGroup = $hybridWorkers | Where-Object { $_.Name -eq $HybridWorkerGroupName }
            
            if ($targetGroup -and $targetGroup.RunbookWorkerCount -gt 0) {
                $hybridWorkerRegistered = $true
                Write-Host "Hybrid worker registered successfully!" -ForegroundColor Green
                Write-Host "Worker count in group: $($targetGroup.RunbookWorkerCount)" -ForegroundColor Green
            } else {
                Write-Host "Attempt $attempt/$maxAttempts - Waiting for hybrid worker registration..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Attempt $attempt/$maxAttempts - Checking hybrid worker status..." -ForegroundColor Yellow
        }
    } while (-not $hybridWorkerRegistered -and $attempt -lt $maxAttempts)
    
    if (-not $hybridWorkerRegistered) {
        Write-Host "Warning: Hybrid worker may still be registering. Check Azure portal for status." -ForegroundColor Yellow
    }
    
    # Display deployment summary
    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "Automation Account: $AutomationAccountName" -ForegroundColor White
    Write-Host "Hybrid Worker Group: $HybridWorkerGroupName" -ForegroundColor White
    Write-Host "Target VM: $ExistingVmName" -ForegroundColor White
    Write-Host "Runbooks Created:" -ForegroundColor White
    Write-Host "  - Get-SystemInfo (Published)" -ForegroundColor White
    Write-Host "  - Restart-Service (Published)" -ForegroundColor White
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Verify hybrid worker registration in Azure portal" -ForegroundColor White
    Write-Host "2. Test runbooks by running them on the hybrid worker group" -ForegroundColor White
    Write-Host "3. Create schedules for automated execution if needed" -ForegroundColor White
    Write-Host "============================================" -ForegroundColor Green
    
} catch {
    Write-Host "`n============================================" -ForegroundColor Red
    Write-Host "DEPLOYMENT FAILED!" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    throw
}