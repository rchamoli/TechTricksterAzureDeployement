param([string]$Name = "World")

Write-Output "Hello, $Name!"
Write-Output "Current time: $(Get-Date)"
Write-Output "Running on: $env:COMPUTERNAME"

# Additional system information
Write-Output "OS Version: $($env:OS)"
Write-Output "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Output "Current Directory: $(Get-Location)"

# Get some basic system info
try {
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    Write-Output "Computer Name: $($computerSystem.Name)"
    Write-Output "Total Physical Memory: $([math]::Round($computerSystem.TotalPhysicalMemory/1GB, 2)) GB"
} catch {
    Write-Output "Could not retrieve computer system information: $($_.Exception.Message)"
}