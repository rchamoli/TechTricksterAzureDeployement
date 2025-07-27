param([string]$ComputerName = "localhost")

Write-Output "Starting runbook execution on $ComputerName"
Write-Output "Current time: $(Get-Date)"

# Get system information
$systemInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory
Write-Output "System Information:"
$systemInfo | Format-List

# Get running services
$services = Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object Name, Status, DisplayName
Write-Output "Running Services Count: $($services.Count)"

# Get disk information
$disks = Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace
Write-Output "Disk Information:"
foreach ($disk in $disks) {
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $totalGB = [math]::Round($disk.Size / 1GB, 2)
    Write-Output "  Drive $($disk.DeviceID): $freeGB GB free of $totalGB GB total"
}

# Get network information
$networkAdapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
Write-Output "Active Network Adapters:"
foreach ($adapter in $networkAdapters) {
    Write-Output "  $($adapter.Name): $($adapter.InterfaceDescription)"
}

Write-Output "Runbook execution completed successfully"