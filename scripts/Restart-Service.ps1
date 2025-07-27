# ================================================================================================
# RESTART-SERVICE RUNBOOK
# ================================================================================================
# Description: This runbook manages Windows services on the hybrid worker
# Author: Azure Automation
# Version: 1.0
# ================================================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceName,
    
    [Parameter(Mandatory=$false)]
    [string]$Action = "Restart",  # Restart, Start, Stop, Status
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 60,
    
    [Parameter(Mandatory=$false)]
    [bool]$WaitForStatus = $true
)

try {
    Write-Output "Starting Service Management Operation..."
    Write-Output "========================================"
    Write-Output "Service Name: $ServiceName"
    Write-Output "Action: $Action"
    Write-Output "Timeout: $TimeoutSeconds seconds"
    Write-Output "========================================"
    
    # Validate service exists
    Write-Output "`n[VALIDATING SERVICE]"
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if (-not $service) {
        throw "Service '$ServiceName' not found on this system."
    }
    
    Write-Output "Service found: $($service.DisplayName)"
    Write-Output "Current Status: $($service.Status)"
    Write-Output "Startup Type: $((Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'").StartMode)"
    
    # Get service dependencies
    $dependencies = $service.DependentServices
    if ($dependencies.Count -gt 0) {
        Write-Output "`nDependent Services:"
        foreach ($dep in $dependencies) {
            Write-Output "  - $($dep.Name) ($($dep.Status))"
        }
    }
    
    $requiredServices = $service.ServicesDependedOn
    if ($requiredServices.Count -gt 0) {
        Write-Output "`nRequired Services:"
        foreach ($req in $requiredServices) {
            Write-Output "  - $($req.Name) ($($req.Status))"
        }
    }
    
    # Perform the requested action
    Write-Output "`n[PERFORMING ACTION: $Action]"
    
    switch ($Action.ToUpper()) {
        "STATUS" {
            Write-Output "Current service status: $($service.Status)"
            
            # Get additional service information
            $serviceWMI = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
            Write-Output "Process ID: $($serviceWMI.ProcessId)"
            Write-Output "Start Mode: $($serviceWMI.StartMode)"
            Write-Output "Service Account: $($serviceWMI.StartName)"
            Write-Output "Path: $($serviceWMI.PathName)"
            Write-Output "Description: $($serviceWMI.Description)"
            
            # Check if process is running and get memory usage
            if ($serviceWMI.ProcessId -and $serviceWMI.ProcessId -ne 0) {
                try {
                    $process = Get-Process -Id $serviceWMI.ProcessId -ErrorAction SilentlyContinue
                    if ($process) {
                        $memoryMB = [math]::Round($process.WorkingSet64/1MB, 2)
                        Write-Output "Memory Usage: $memoryMB MB"
                        Write-Output "CPU Time: $($process.TotalProcessorTime)"
                        Write-Output "Start Time: $($process.StartTime)"
                    }
                } catch {
                    Write-Output "Could not retrieve process information."
                }
            }
        }
        
        "START" {
            if ($service.Status -eq 'Running') {
                Write-Output "Service is already running."
            } else {
                Write-Output "Starting service..."
                Start-Service -Name $ServiceName -ErrorAction Stop
                
                if ($WaitForStatus) {
                    Write-Output "Waiting for service to start (timeout: $TimeoutSeconds seconds)..."
                    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
                    
                    do {
                        Start-Sleep -Seconds 2
                        $service = Get-Service -Name $ServiceName
                        Write-Output "Current status: $($service.Status)"
                    } while ($service.Status -ne 'Running' -and (Get-Date) -lt $timeout)
                    
                    if ($service.Status -eq 'Running') {
                        Write-Output "Service started successfully!"
                    } else {
                        throw "Service failed to start within the timeout period."
                    }
                }
            }
        }
        
        "STOP" {
            if ($service.Status -eq 'Stopped') {
                Write-Output "Service is already stopped."
            } else {
                # Check for dependent services
                $runningDependents = $service.DependentServices | Where-Object { $_.Status -eq 'Running' }
                if ($runningDependents.Count -gt 0) {
                    Write-Output "Warning: The following dependent services will also be stopped:"
                    foreach ($dep in $runningDependents) {
                        Write-Output "  - $($dep.Name)"
                    }
                }
                
                Write-Output "Stopping service..."
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                
                if ($WaitForStatus) {
                    Write-Output "Waiting for service to stop (timeout: $TimeoutSeconds seconds)..."
                    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
                    
                    do {
                        Start-Sleep -Seconds 2
                        $service = Get-Service -Name $ServiceName
                        Write-Output "Current status: $($service.Status)"
                    } while ($service.Status -ne 'Stopped' -and (Get-Date) -lt $timeout)
                    
                    if ($service.Status -eq 'Stopped') {
                        Write-Output "Service stopped successfully!"
                    } else {
                        throw "Service failed to stop within the timeout period."
                    }
                }
            }
        }
        
        "RESTART" {
            # Check for dependent services before restart
            $runningDependents = $service.DependentServices | Where-Object { $_.Status -eq 'Running' }
            if ($runningDependents.Count -gt 0) {
                Write-Output "Warning: The following dependent services will be affected:"
                foreach ($dep in $runningDependents) {
                    Write-Output "  - $($dep.Name)"
                }
            }
            
            if ($service.Status -eq 'Running') {
                Write-Output "Stopping service..."
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                
                if ($WaitForStatus) {
                    Write-Output "Waiting for service to stop..."
                    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
                    
                    do {
                        Start-Sleep -Seconds 2
                        $service = Get-Service -Name $ServiceName
                        Write-Output "Current status: $($service.Status)"
                    } while ($service.Status -ne 'Stopped' -and (Get-Date) -lt $timeout)
                    
                    if ($service.Status -ne 'Stopped') {
                        throw "Service failed to stop within the timeout period."
                    }
                }
            }
            
            Write-Output "Starting service..."
            Start-Service -Name $ServiceName -ErrorAction Stop
            
            if ($WaitForStatus) {
                Write-Output "Waiting for service to start..."
                $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
                
                do {
                    Start-Sleep -Seconds 2
                    $service = Get-Service -Name $ServiceName
                    Write-Output "Current status: $($service.Status)"
                } while ($service.Status -ne 'Running' -and (Get-Date) -lt $timeout)
                
                if ($service.Status -eq 'Running') {
                    Write-Output "Service restarted successfully!"
                } else {
                    throw "Service failed to start within the timeout period."
                }
            }
        }
        
        default {
            throw "Invalid action specified. Valid actions are: Status, Start, Stop, Restart"
        }
    }
    
    # Final status check
    Write-Output "`n[FINAL STATUS]"
    $finalService = Get-Service -Name $ServiceName
    Write-Output "Service Name: $($finalService.Name)"
    Write-Output "Display Name: $($finalService.DisplayName)"
    Write-Output "Final Status: $($finalService.Status)"
    
    # Log the action to Windows Event Log
    try {
        $eventSource = "Azure Automation"
        if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
            [System.Diagnostics.EventLog]::CreateEventSource($eventSource, "Application")
        }
        
        $eventMessage = "Azure Automation Runbook performed '$Action' action on service '$ServiceName'. Final status: $($finalService.Status)"
        Write-EventLog -LogName Application -Source $eventSource -EventId 1001 -EntryType Information -Message $eventMessage
        Write-Output "Event logged to Windows Event Log."
    } catch {
        Write-Output "Could not write to Windows Event Log: $($_.Exception.Message)"
    }
    
    Write-Output "`n========================================"
    Write-Output "Service Management Operation Completed Successfully!"
    
} catch {
    Write-Error "An error occurred during service management: $($_.Exception.Message)"
    Write-Error "Stack Trace: $($_.Exception.StackTrace)"
    
    # Log error to Windows Event Log
    try {
        $eventSource = "Azure Automation"
        if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
            [System.Diagnostics.EventLog]::CreateEventSource($eventSource, "Application")
        }
        
        $errorMessage = "Azure Automation Runbook failed to perform '$Action' action on service '$ServiceName'. Error: $($_.Exception.Message)"
        Write-EventLog -LogName Application -Source $eventSource -EventId 1002 -EntryType Error -Message $errorMessage
    } catch {
        # Ignore event log errors
    }
    
    throw
}