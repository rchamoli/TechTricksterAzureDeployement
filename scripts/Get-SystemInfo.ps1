# ================================================================================================
# GET-SYSTEMINFO RUNBOOK
# ================================================================================================
# Description: This runbook collects comprehensive system information from the hybrid worker
# Author: Azure Automation
# Version: 1.0
# ================================================================================================

param()

try {
    Write-Output "Starting System Information Collection..."
    Write-Output "============================================"
    
    # Get Computer Information
    Write-Output "`n[COMPUTER INFORMATION]"
    $computerInfo = Get-ComputerInfo -Property @(
        'ComputerName', 
        'Domain', 
        'Workgroup', 
        'WindowsProductName', 
        'WindowsVersion', 
        'TotalPhysicalMemory',
        'AvailablePhysicalMemory',
        'TotalVirtualMemory',
        'AvailableVirtualMemory'
    )
    
    Write-Output "Computer Name: $($computerInfo.ComputerName)"
    Write-Output "Domain: $($computerInfo.Domain)"
    Write-Output "Workgroup: $($computerInfo.Workgroup)"
    Write-Output "OS: $($computerInfo.WindowsProductName)"
    Write-Output "Version: $($computerInfo.WindowsVersion)"
    Write-Output "Total Physical Memory: $([math]::Round($computerInfo.TotalPhysicalMemory/1GB, 2)) GB"
    Write-Output "Available Physical Memory: $([math]::Round($computerInfo.AvailablePhysicalMemory/1GB, 2)) GB"
    
    # Get Processor Information
    Write-Output "`n[PROCESSOR INFORMATION]"
    $processors = Get-WmiObject -Class Win32_Processor
    foreach ($processor in $processors) {
        Write-Output "Processor: $($processor.Name)"
        Write-Output "Cores: $($processor.NumberOfCores)"
        Write-Output "Logical Processors: $($processor.NumberOfLogicalProcessors)"
        Write-Output "Max Clock Speed: $($processor.MaxClockSpeed) MHz"
        Write-Output "Current Load: $($processor.LoadPercentage)%"
    }
    
    # Get Disk Information
    Write-Output "`n[DISK INFORMATION]"
    $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($disk in $disks) {
        $totalSize = [math]::Round($disk.Size/1GB, 2)
        $freeSpace = [math]::Round($disk.FreeSpace/1GB, 2)
        $usedSpace = $totalSize - $freeSpace
        $percentFree = [math]::Round(($freeSpace / $totalSize) * 100, 2)
        
        Write-Output "Drive: $($disk.DeviceID)"
        Write-Output "  Total Size: $totalSize GB"
        Write-Output "  Used Space: $usedSpace GB"
        Write-Output "  Free Space: $freeSpace GB ($percentFree% free)"
        Write-Output "  File System: $($disk.FileSystem)"
    }
    
    # Get Network Information
    Write-Output "`n[NETWORK INFORMATION]"
    $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
    foreach ($adapter in $networkAdapters) {
        Write-Output "Adapter: $($adapter.Description)"
        if ($adapter.IPAddress) {
            Write-Output "  IP Address(es): $($adapter.IPAddress -join ', ')"
        }
        if ($adapter.DefaultIPGateway) {
            Write-Output "  Gateway: $($adapter.DefaultIPGateway -join ', ')"
        }
        if ($adapter.DNSServerSearchOrder) {
            Write-Output "  DNS Servers: $($adapter.DNSServerSearchOrder -join ', ')"
        }
        Write-Output "  MAC Address: $($adapter.MACAddress)"
        Write-Output "  DHCP Enabled: $($adapter.DHCPEnabled)"
    }
    
    # Get Running Services (top 10 by memory usage)
    Write-Output "`n[TOP SERVICES BY MEMORY USAGE]"
    $services = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
    foreach ($service in $services) {
        $memoryMB = [math]::Round($service.WorkingSet/1MB, 2)
        Write-Output "$($service.ProcessName): $memoryMB MB"
    }
    
    # Get System Uptime
    Write-Output "`n[SYSTEM UPTIME]"
    $bootTime = (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime
    $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($bootTime)
    $uptime = (Get-Date) - $bootTime
    Write-Output "Last Boot: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Output "Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    
    # Get Windows Updates Information
    Write-Output "`n[WINDOWS UPDATES STATUS]"
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0")
        Write-Output "Pending Updates: $($searchResult.Updates.Count)"
        
        if ($searchResult.Updates.Count -gt 0) {
            Write-Output "Sample pending updates:"
            $searchResult.Updates | Select-Object -First 5 | ForEach-Object {
                Write-Output "  - $($_.Title)"
            }
        }
    }
    catch {
        Write-Output "Could not retrieve Windows Updates information: $($_.Exception.Message)"
    }
    
    # Get Event Log Errors (last 24 hours)
    Write-Output "`n[RECENT SYSTEM ERRORS]"
    try {
        $errors = Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddDays(-1) | Select-Object -First 5
        if ($errors) {
            foreach ($error in $errors) {
                Write-Output "[$($error.TimeGenerated)] $($error.Source): $($error.Message.Substring(0, [Math]::Min(100, $error.Message.Length)))..."
            }
        } else {
            Write-Output "No system errors found in the last 24 hours."
        }
    }
    catch {
        Write-Output "Could not retrieve system errors: $($_.Exception.Message)"
    }
    
    # Get Azure VM Metadata (if running on Azure VM)
    Write-Output "`n[AZURE VM METADATA]"
    try {
        $metadata = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" -Headers @{Metadata="true"} -TimeoutSec 5
        Write-Output "VM Name: $($metadata.compute.name)"
        Write-Output "VM Size: $($metadata.compute.vmSize)"
        Write-Output "Location: $($metadata.compute.location)"
        Write-Output "Resource Group: $($metadata.compute.resourceGroupName)"
        Write-Output "Subscription ID: $($metadata.compute.subscriptionId)"
    }
    catch {
        Write-Output "Not running on Azure VM or metadata service unavailable."
    }
    
    Write-Output "`n============================================"
    Write-Output "System Information Collection Completed Successfully!"
    
} catch {
    Write-Error "An error occurred during system information collection: $($_.Exception.Message)"
    Write-Error "Stack Trace: $($_.Exception.StackTrace)"
    throw
}