# ================================================================================================
# PREREQUISITE VALIDATION SCRIPT
# ================================================================================================
# Description: Validates prerequisites before deploying the Azure Automation Account template
# Author: Azure Automation Team
# Version: 1.0
# ================================================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ExistingVmResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ExistingVmName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

Write-Host "============================================" -ForegroundColor Green
Write-Host "Azure Automation Prerequisites Validation" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

$validationPassed = $true

# Check Azure PowerShell module
Write-Host "`n[CHECK 1] Azure PowerShell Module..." -ForegroundColor Yellow
try {
    $azModule = Get-Module -Name Az -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if ($azModule) {
        Write-Host "✅ Azure PowerShell module found: Version $($azModule.Version)" -ForegroundColor Green
    } else {
        Write-Host "❌ Azure PowerShell module not found. Please install it using: Install-Module -Name Az" -ForegroundColor Red
        $validationPassed = $false
    }
} catch {
    Write-Host "❌ Error checking Azure PowerShell module: $($_.Exception.Message)" -ForegroundColor Red
    $validationPassed = $false
}

# Check Azure login status
Write-Host "`n[CHECK 2] Azure Login Status..." -ForegroundColor Yellow
try {
    $context = Get-AzContext
    if ($context) {
        Write-Host "✅ Logged in to Azure as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "   Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Green
    } else {
        Write-Host "❌ Not logged in to Azure. Please run: Connect-AzAccount" -ForegroundColor Red
        $validationPassed = $false
    }
} catch {
    Write-Host "❌ Error checking Azure login: $($_.Exception.Message)" -ForegroundColor Red
    $validationPassed = $false
}

# Check Bicep CLI
Write-Host "`n[CHECK 3] Bicep CLI..." -ForegroundColor Yellow
try {
    $bicepVersion = & bicep --version 2>$null
    if ($bicepVersion) {
        Write-Host "✅ Bicep CLI found: $bicepVersion" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Bicep CLI not found. It's optional but recommended for direct Bicep deployments." -ForegroundColor Yellow
        Write-Host "   You can still deploy using Azure CLI or PowerShell." -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Bicep CLI not found. It's optional but recommended." -ForegroundColor Yellow
}

# Check Azure CLI
Write-Host "`n[CHECK 4] Azure CLI..." -ForegroundColor Yellow
try {
    $azCliVersion = & az version --output json 2>$null | ConvertFrom-Json
    if ($azCliVersion) {
        Write-Host "✅ Azure CLI found: Version $($azCliVersion.'azure-cli')" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Azure CLI not found. It's optional but can be used for deployment." -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Azure CLI not found. It's optional." -ForegroundColor Yellow
}

# Validate existing VM
Write-Host "`n[CHECK 5] Existing VM Validation..." -ForegroundColor Yellow
if ($context) {
    try {
        $vm = Get-AzVM -ResourceGroupName $ExistingVmResourceGroupName -Name $ExistingVmName -ErrorAction Stop
        Write-Host "✅ VM '$ExistingVmName' found successfully" -ForegroundColor Green
        Write-Host "   Resource Group: $($vm.ResourceGroupName)" -ForegroundColor Green
        Write-Host "   Location: $($vm.Location)" -ForegroundColor Green
        Write-Host "   VM Size: $($vm.HardwareProfile.VmSize)" -ForegroundColor Green
        Write-Host "   OS Type: $($vm.StorageProfile.OsDisk.OsType)" -ForegroundColor Green
        Write-Host "   VM ID: $($vm.Id)" -ForegroundColor Green
        
        # Check if VM is Windows
        if ($vm.StorageProfile.OsDisk.OsType -ne "Windows") {
            Write-Host "❌ VM is not Windows-based. Hybrid Worker extension requires Windows VM." -ForegroundColor Red
            $validationPassed = $false
        }
        
        # Check VM power state
        $vmStatus = Get-AzVM -ResourceGroupName $ExistingVmResourceGroupName -Name $ExistingVmName -Status
        $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
        Write-Host "   Power State: $powerState" -ForegroundColor Green
        
        if ($powerState -ne "VM running") {
            Write-Host "⚠️ VM is not currently running. It should be running for extension installation." -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ Error validating VM: $($_.Exception.Message)" -ForegroundColor Red
        $validationPassed = $false
    }
} else {
    Write-Host "⏭️ Skipping VM validation (not logged in to Azure)" -ForegroundColor Yellow
}

# Check required permissions
Write-Host "`n[CHECK 6] Permission Validation..." -ForegroundColor Yellow
if ($context) {
    try {
        # Check if user can create resource groups
        $testRgName = "test-permissions-validation-$(Get-Random)"
        try {
            $testRg = New-AzResourceGroup -Name $testRgName -Location "East US" -ErrorAction Stop
            Remove-AzResourceGroup -Name $testRgName -Force -ErrorAction SilentlyContinue
            Write-Host "✅ Resource group creation permissions verified" -ForegroundColor Green
        } catch {
            Write-Host "❌ Insufficient permissions to create resource groups: $($_.Exception.Message)" -ForegroundColor Red
            $validationPassed = $false
        }
        
        # Check VM extension permissions
        try {
            $extensions = Get-AzVMExtension -ResourceGroupName $ExistingVmResourceGroupName -VMName $ExistingVmName -ErrorAction Stop
            Write-Host "✅ VM extension read permissions verified" -ForegroundColor Green
        } catch {
            Write-Host "❌ Insufficient permissions to access VM extensions: $($_.Exception.Message)" -ForegroundColor Red
            $validationPassed = $false
        }
        
    } catch {
        Write-Host "❌ Error validating permissions: $($_.Exception.Message)" -ForegroundColor Red
        $validationPassed = $false
    }
} else {
    Write-Host "⏭️ Skipping permission validation (not logged in to Azure)" -ForegroundColor Yellow
}

# Check required files
Write-Host "`n[CHECK 7] Required Files..." -ForegroundColor Yellow
$requiredFiles = @(
    "main.bicep",
    "scripts/Get-SystemInfo.ps1",
    "scripts/Restart-Service.ps1",
    "deploy-automation.ps1"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ Found: $file" -ForegroundColor Green
    } else {
        Write-Host "❌ Missing: $file" -ForegroundColor Red
        $validationPassed = $false
    }
}

# Check network connectivity to Azure
Write-Host "`n[CHECK 8] Network Connectivity..." -ForegroundColor Yellow
try {
    $response = Test-NetConnection -ComputerName "management.azure.com" -Port 443 -WarningAction SilentlyContinue
    if ($response.TcpTestSucceeded) {
        Write-Host "✅ Network connectivity to Azure verified" -ForegroundColor Green
    } else {
        Write-Host "❌ Cannot reach Azure management endpoints" -ForegroundColor Red
        $validationPassed = $false
    }
} catch {
    Write-Host "⚠️ Could not test network connectivity: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Final validation result
Write-Host "`n============================================" -ForegroundColor Green
if ($validationPassed) {
    Write-Host "✅ ALL PREREQUISITES VALIDATED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "You can proceed with the deployment." -ForegroundColor Green
    
    if ($vm) {
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "1. Update main.bicepparam with your VM details:" -ForegroundColor White
        Write-Host "   existingVmResourceId = '$($vm.Id)'" -ForegroundColor Cyan
        Write-Host "   existingVmResourceGroupName = '$($vm.ResourceGroupName)'" -ForegroundColor Cyan
        Write-Host "   existingVmName = '$($vm.Name)'" -ForegroundColor Cyan
        Write-Host "`n2. Run the deployment script:" -ForegroundColor White
        Write-Host "   .\deploy-automation.ps1 -ResourceGroupName 'rg-automation-demo' -ExistingVmResourceId '$($vm.Id)' -ExistingVmResourceGroupName '$($vm.ResourceGroupName)' -ExistingVmName '$($vm.Name)'" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ PREREQUISITE VALIDATION FAILED!" -ForegroundColor Red
    Write-Host "Please address the issues above before proceeding with deployment." -ForegroundColor Red
    exit 1
}
Write-Host "============================================" -ForegroundColor Green