param([string]$Path = "C:\")

Write-Output "Getting disk space information for: $Path"
Write-Output "Script started at: $(Get-Date)"

# Get disk information for the specified path
$diskInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq $Path.Substring(0,2)}

if ($diskInfo) {
    Write-Output "=== Disk Information ==="
    Write-Output "Drive: $($diskInfo.DeviceID)"
    Write-Output "Volume Name: $($diskInfo.VolumeName)"
    Write-Output "File System: $($diskInfo.FileSystem)"
    Write-Output "Total Space: $([math]::Round($diskInfo.Size/1GB, 2)) GB"
    Write-Output "Free Space: $([math]::Round($diskInfo.FreeSpace/1GB, 2)) GB"
    Write-Output "Used Space: $([math]::Round(($diskInfo.Size - $diskInfo.FreeSpace)/1GB, 2)) GB"
    
    # Calculate percentage used
    $percentUsed = [math]::Round((($diskInfo.Size - $diskInfo.FreeSpace) / $diskInfo.Size) * 100, 2)
    Write-Output "Percentage Used: $percentUsed%"
    
    # Warning if disk usage is high
    if ($percentUsed -gt 80) {
        Write-Output "WARNING: Disk usage is above 80%!"
    } elseif ($percentUsed -gt 70) {
        Write-Output "NOTICE: Disk usage is above 70%"
    } else {
        Write-Output "Disk usage is within normal range"
    }
} else {
    Write-Output "ERROR: Could not retrieve disk information for $Path"
    Write-Output "Available drives:"
    Get-WmiObject -Class Win32_LogicalDisk | ForEach-Object {
        Write-Output "  $($_.DeviceID) - $($_.VolumeName)"
    }
}

Write-Output "Script completed at: $(Get-Date)"