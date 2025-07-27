param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AutomationAccountName
)

Write-Host "Validating Automation Account deployment..." -ForegroundColor Green

# Check if resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Error "Resource group '$ResourceGroupName' not found!"
    exit 1
}

Write-Host "✓ Resource group '$ResourceGroupName' exists" -ForegroundColor Green

# Check if automation account exists
$automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue
if (-not $automationAccount) {
    Write-Error "Automation Account '$AutomationAccountName' not found!"
    exit 1
}

Write-Host "✓ Automation Account '$AutomationAccountName' exists" -ForegroundColor Green

# Check hybrid worker groups
$workerGroups = Get-AzAutomationHybridRunbookWorkerGroup -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
if ($workerGroups) {
    Write-Host "✓ Hybrid Worker Groups found:" -ForegroundColor Green
    foreach ($group in $workerGroups) {
        Write-Host "  - $($group.Name)" -ForegroundColor Cyan
        
        # Check workers in the group
        $workers = Get-AzAutomationHybridRunbookWorker -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -HybridRunbookWorkerGroupName $group.Name -ErrorAction SilentlyContinue
        if ($workers) {
            Write-Host "    Workers:" -ForegroundColor Yellow
            foreach ($worker in $workers) {
                Write-Host "      - $($worker.Name) (LastSeen: $($worker.LastSeenDateTime))" -ForegroundColor White
            }
        } else {
            Write-Host "    No workers found in this group" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "⚠ No Hybrid Worker Groups found" -ForegroundColor Yellow
}

# Check runbooks
$runbooks = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
if ($runbooks) {
    Write-Host "✓ Runbooks found:" -ForegroundColor Green
    foreach ($runbook in $runbooks) {
        $status = if ($runbook.State -eq "Published") { "✓ Published" } else { "⚠ Draft" }
        Write-Host "  - $($runbook.Name) ($($runbook.RunbookType)) - $status" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠ No runbooks found" -ForegroundColor Yellow
}

# Check Run As accounts
$runAsAccounts = Get-AzAutomationRunAsAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
if ($runAsAccounts) {
    Write-Host "✓ Run As accounts found:" -ForegroundColor Green
    foreach ($account in $runAsAccounts) {
        Write-Host "  - $($account.Name)" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠ No Run As accounts found" -ForegroundColor Yellow
}

# Check credentials
$credentials = Get-AzAutomationCredential -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
if ($credentials) {
    Write-Host "✓ Credentials found:" -ForegroundColor Green
    foreach ($cred in $credentials) {
        Write-Host "  - $($cred.Name)" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠ No credentials found" -ForegroundColor Yellow
}

Write-Host "`nValidation completed!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Install Hybrid Runbook Worker on your VM if not already done" -ForegroundColor White
Write-Host "2. Test runbook execution in the Azure Portal" -ForegroundColor White
Write-Host "3. Configure Run As account if needed for Azure resource access" -ForegroundColor White