function New-OofFooScheduledTask {
    <#
    .SYNOPSIS
        Creates a scheduled task for oof-foo maintenance

    .DESCRIPTION
        Creates a Windows scheduled task to run oof-foo maintenance automatically.
        Requires administrator privileges.

    .PARAMETER TaskName
        Name for the scheduled task (default: "oof-foo Maintenance")

    .PARAMETER Frequency
        How often to run: Daily, Weekly, Monthly

    .PARAMETER Time
        Time of day to run (24-hour format, e.g., "03:00")

    .PARAMETER DayOfWeek
        Day of week for weekly tasks (Sunday, Monday, etc.)

    .PARAMETER MaintenanceType
        Type of maintenance: Full, UpdatesOnly, CleanupOnly

    .PARAMETER RunAsSystem
        Run as SYSTEM account instead of current user

    .EXAMPLE
        New-OofFooScheduledTask -Frequency Weekly -DayOfWeek Sunday -Time "03:00"

    .EXAMPLE
        New-OofFooScheduledTask -Frequency Daily -Time "02:00" -MaintenanceType UpdatesOnly
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TaskName = "oof-foo Maintenance",

        [Parameter(Mandatory)]
        [ValidateSet('Daily', 'Weekly', 'Monthly')]
        [string]$Frequency,

        [Parameter()]
        [string]$Time = "03:00",

        [Parameter()]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$DayOfWeek = "Sunday",

        [Parameter()]
        [ValidateSet('Full', 'UpdatesOnly', 'CleanupOnly', 'HealthCheckOnly')]
        [string]$MaintenanceType = "Full",

        [Parameter()]
        [switch]$RunAsSystem
    )

    # Check admin privileges
    if (-not (Test-OofFooAdministrator)) {
        Write-Error "Administrator privileges required to create scheduled tasks"
        return
    }

    Write-OofFooLog "Creating scheduled task: $TaskName" -Level Information

    # Get module path
    $modulePath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    # Create script based on maintenance type
    $scriptContent = switch ($MaintenanceType) {
        'Full' {
            @"
Import-Module '$modulePath\src\OofFoo\OofFoo.psd1' -Force
Write-OofFooLog "Scheduled task: Starting full maintenance" -Level Information
try {
    `$results = @{}
    `$results.Health = Get-SystemHealth
    `$results.Updates = Invoke-SystemUpdate -UpdateType All -SkipConfirmation
    `$results.Maintenance = Invoke-SystemMaintenance -DeepClean -SkipConfirmation -SkipRestorePoint
    `$results.Patches = Invoke-SystemPatch
    Write-OofFooLog "Scheduled task: Full maintenance completed successfully" -Level Information
} catch {
    Write-OofFooLog "Scheduled task error: `$_" -Level Error
}
"@
        }
        'UpdatesOnly' {
            @"
Import-Module '$modulePath\src\OofFoo\OofFoo.psd1' -Force
Write-OofFooLog "Scheduled task: Starting updates" -Level Information
try {
    `$result = Invoke-SystemUpdate -UpdateType All -SkipConfirmation
    Write-OofFooLog "Scheduled task: Updates completed" -Level Information
} catch {
    Write-OofFooLog "Scheduled task error: `$_" -Level Error
}
"@
        }
        'CleanupOnly' {
            @"
Import-Module '$modulePath\src\OofFoo\OofFoo.psd1' -Force
Write-OofFooLog "Scheduled task: Starting cleanup" -Level Information
try {
    `$result = Invoke-SystemMaintenance -DeepClean -SkipConfirmation -SkipRestorePoint
    Write-OofFooLog "Scheduled task: Cleanup completed. Freed: `$(`$result.SpaceFreedMB) MB" -Level Information
} catch {
    Write-OofFooLog "Scheduled task error: `$_" -Level Error
}
"@
        }
        'HealthCheckOnly' {
            @"
Import-Module '$modulePath\src\OofFoo\OofFoo.psd1' -Force
Write-OofFooLog "Scheduled task: Running health check" -Level Information
try {
    `$result = Get-SystemHealth
    Write-OofFooLog "Scheduled task: Health check completed. Status: `$(`$result.OverallHealth)" -Level Information
} catch {
    Write-OofFooLog "Scheduled task error: `$_" -Level Error
}
"@
        }
    }

    # Save script to temp location
    $scriptPath = Join-Path $env:ProgramData "OofFoo"
    if (-not (Test-Path $scriptPath)) {
        New-Item -Path $scriptPath -ItemType Directory -Force | Out-Null
    }

    $scriptFile = Join-Path $scriptPath "ScheduledMaintenance.ps1"
    $scriptContent | Out-File -FilePath $scriptFile -Encoding UTF8 -Force

    Write-OofFooLog "Script saved to: $scriptFile" -Level Verbose

    # Create scheduled task action
    $action = New-ScheduledTaskAction `
        -Execute "PowerShell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptFile`""

    # Create trigger based on frequency
    $trigger = switch ($Frequency) {
        'Daily' {
            New-ScheduledTaskTrigger -Daily -At $Time
        }
        'Weekly' {
            New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $Time
        }
        'Monthly' {
            New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek $DayOfWeek -At $Time
        }
    }

    # Create principal (user context)
    if ($RunAsSystem) {
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    } else {
        $principal = New-ScheduledTaskPrincipal -UserId (whoami) -LogonType Interactive -RunLevel Highest
    }

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 4)

    # Register task
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Description "oof-foo automatic system maintenance ($MaintenanceType)" `
            -Force | Out-Null

        Write-OofFooLog "Scheduled task created successfully: $TaskName" -Level Information

        return [PSCustomObject]@{
            Success = $true
            TaskName = $TaskName
            Frequency = $Frequency
            Time = $Time
            MaintenanceType = $MaintenanceType
            ScriptPath = $scriptFile
            Message = "Task created successfully"
        }
    }
    catch {
        Write-OofFooLog "Failed to create scheduled task: $_" -Level Error
        throw "Failed to create scheduled task: $_"
    }
}

function Remove-OofFooScheduledTask {
    <#
    .SYNOPSIS
        Removes an oof-foo scheduled task

    .DESCRIPTION
        Removes a previously created oof-foo scheduled task.
        Requires administrator privileges.

    .PARAMETER TaskName
        Name of the task to remove

    .EXAMPLE
        Remove-OofFooScheduledTask -TaskName "oof-foo Maintenance"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    if (-not (Test-OofFooAdministrator)) {
        Write-Error "Administrator privileges required to remove scheduled tasks"
        return
    }

    Write-OofFooLog "Removing scheduled task: $TaskName" -Level Information

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-OofFooLog "Scheduled task removed: $TaskName" -Level Information

        return [PSCustomObject]@{
            Success = $true
            TaskName = $TaskName
            Message = "Task removed successfully"
        }
    }
    catch {
        Write-OofFooLog "Failed to remove scheduled task: $_" -Level Error
        throw "Failed to remove scheduled task: $_"
    }
}

function Get-OofFooScheduledTask {
    <#
    .SYNOPSIS
        Gets information about oof-foo scheduled tasks

    .DESCRIPTION
        Retrieves information about existing oof-foo scheduled tasks.

    .PARAMETER TaskName
        Specific task name to query (optional)

    .EXAMPLE
        Get-OofFooScheduledTask

    .EXAMPLE
        Get-OofFooScheduledTask -TaskName "oof-foo Maintenance"
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TaskName
    )

    try {
        if ($TaskName) {
            $tasks = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        } else {
            $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*oof-foo*" }
        }

        if (-not $tasks) {
            Write-Host "No oof-foo scheduled tasks found." -ForegroundColor Yellow
            return
        }

        $results = @()
        foreach ($task in $tasks) {
            $info = Get-ScheduledTaskInfo -TaskName $task.TaskName

            $results += [PSCustomObject]@{
                TaskName = $task.TaskName
                State = $task.State
                Enabled = $task.Settings.Enabled
                LastRunTime = $info.LastRunTime
                LastResult = $info.LastTaskResult
                NextRunTime = $info.NextRunTime
                Trigger = $task.Triggers[0].CimClass.CimClassName
                Description = $task.Description
            }
        }

        return $results
    }
    catch {
        Write-Error "Failed to query scheduled tasks: $_"
    }
}

function Test-OofFooScheduledTask {
    <#
    .SYNOPSIS
        Tests an oof-foo scheduled task by running it immediately

    .DESCRIPTION
        Triggers an oof-foo scheduled task to run immediately for testing.
        Requires administrator privileges.

    .PARAMETER TaskName
        Name of the task to test

    .EXAMPLE
        Test-OofFooScheduledTask -TaskName "oof-foo Maintenance"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    if (-not (Test-OofFooAdministrator)) {
        Write-Error "Administrator privileges required to run scheduled tasks"
        return
    }

    Write-OofFooLog "Testing scheduled task: $TaskName" -Level Information

    try {
        Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        Write-Host "Task started. Check logs for results: Get-OofFooLogs -Last 50" -ForegroundColor Green

        return [PSCustomObject]@{
            Success = $true
            TaskName = $TaskName
            Message = "Task started successfully"
        }
    }
    catch {
        Write-OofFooLog "Failed to start scheduled task: $_" -Level Error
        throw "Failed to start scheduled task: $_"
    }
}
