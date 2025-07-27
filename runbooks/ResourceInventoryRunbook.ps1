param([string]$ResourceGroupName)

Write-Output "Starting resource inventory runbook"
Write-Output "Current time: $(Get-Date)"

# Get all resources in the specified resource group
$resources = Get-AzResource -ResourceGroupName $ResourceGroupName

Write-Output "Resources in Resource Group '$ResourceGroupName':"
foreach ($resource in $resources) {
    Write-Output "  - $($resource.Name) ($($resource.Type))"
}

Write-Output "Total resources found: $($resources.Count)"

# Get VM information
$vms = Get-AzVM -ResourceGroupName $ResourceGroupName
Write-Output "Virtual Machines:"
foreach ($vm in $vms) {
    Write-Output "  - $($vm.Name) (Status: $($vm.PowerState))"
}

# Get storage accounts
$storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName
Write-Output "Storage Accounts:"
foreach ($sa in $storageAccounts) {
    Write-Output "  - $($sa.StorageAccountName) (SKU: $($sa.Sku.Name))"
}

# Get network interfaces
$nics = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName
Write-Output "Network Interfaces:"
foreach ($nic in $nics) {
    Write-Output "  - $($nic.Name) (Subnet: $($nic.IpConfigurations.Subnet.Id))"
}

# Get public IP addresses
$publicIPs = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName
Write-Output "Public IP Addresses:"
foreach ($pip in $publicIPs) {
    Write-Output "  - $($pip.Name) (IP: $($pip.IpAddress))"
}

Write-Output "Resource inventory completed successfully"