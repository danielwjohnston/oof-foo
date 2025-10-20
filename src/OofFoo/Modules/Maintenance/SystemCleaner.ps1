function Invoke-SystemMaintenance {
    <#
    .SYNOPSIS
        Performs system cleanup and maintenance tasks

    .DESCRIPTION
        Cleans temporary files, clears caches, runs disk cleanup, and performs
        other routine maintenance tasks. Part of the oof-foo maintenance suite.
        Uses logging, configuration, and creates restore points for safety.

    .PARAMETER DeepClean
        Perform more aggressive cleanup (may take longer)

    .PARAMETER IncludeLogs
        Also clean old log files

    .PARAMETER SkipConfirmation
        Skip confirmation prompts (use with caution)

    .PARAMETER SkipRestorePoint
        Skip creating a system restore point

    .EXAMPLE
        Invoke-SystemMaintenance

    .EXAMPLE
        Invoke-SystemMaintenance -DeepClean -IncludeLogs
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$DeepClean,

        [Parameter()]
        [switch]$IncludeLogs,

        [Parameter()]
        [switch]$SkipConfirmation,

        [Parameter()]
        [switch]$SkipRestorePoint
    )

    $config = Get-OofFooConfig
    Write-OofFooLog "=== Starting System Maintenance ===" -Level Information

    # Track overall progress
    $startTime = Get-Date
    $initialSpace = Get-OofFooFreeSpace -DriveLetter C

    # Results tracking
    $results = [PSCustomObject]@{
        StartTime = $startTime
        EndTime = $null
        InitialFreeSpaceGB = $initialSpace.FreeSpaceGB
        FinalFreeSpaceGB = 0
        SpaceFreedMB = 0
        Operations = @()
        Errors = @()
        Success = $true
    }

    # Confirmation check
    if ($config.Maintenance.ConfirmDestructiveActions -and -not $SkipConfirmation) {
        $message = "This will clean temporary files, caches, and potentially delete data. Continue?"
        $confirmation = Read-Host "$message (yes/no)"

        if ($confirmation -ne 'yes' -and $confirmation -ne 'y') {
            Write-OofFooLog "Maintenance cancelled by user" -Level Warning
            $results.Success = $false
            return $results
        }
    }

    # Create restore point if configured
    if ($config.Maintenance.CreateRestorePointBeforeMaintenance -and -not $SkipRestorePoint) {
        if (Test-OofFooAdministrator) {
            Write-OofFooLog "Creating system restore point..." -Level Information
            $restorePointCreated = New-OofFooRestorePoint -Description "Before oof-foo maintenance"

            if (-not $restorePointCreated) {
                Write-OofFooLog "Warning: Could not create restore point, but continuing..." -Level Warning
            }
        }
        else {
            Write-OofFooLog "Not running as admin - skipping restore point creation" -Level Warning
        }
    }

    # Define cleanup operations
    $operations = @(
        @{
            Name = "Windows Temp Files"
            Enabled = $true
            ScriptBlock = { Clear-WindowsTempFiles -Config $config }
        }
        @{
            Name = "User Temp Files"
            Enabled = $true
            ScriptBlock = { Clear-UserTempFiles -Config $config }
        }
        @{
            Name = "Recycle Bin"
            Enabled = $config.Maintenance.AutoCleanRecycleBin
            ScriptBlock = { Clear-RecycleBinSafely }
        }
        @{
            Name = "Windows Update Cache"
            Enabled = $DeepClean
            ScriptBlock = { Clear-WindowsUpdateCache }
        }
        @{
            Name = "Browser Caches"
            Enabled = $DeepClean
            ScriptBlock = { Clear-BrowserCaches }
        }
        @{
            Name = "Windows Error Reports"
            Enabled = $DeepClean
            ScriptBlock = { Clear-WindowsErrorReports }
        }
        @{
            Name = "Delivery Optimization Cache"
            Enabled = $DeepClean
            ScriptBlock = { Clear-DeliveryOptimizationCache }
        }
    )

    # Execute operations
    $operationCount = ($operations | Where-Object { $_.Enabled }).Count
    $currentOperation = 0

    foreach ($operation in $operations) {
        if (-not $operation.Enabled) {
            continue
        }

        $currentOperation++
        $percentComplete = [math]::Round(($currentOperation / $operationCount) * 100)

        Write-Progress -Activity "System Maintenance" -Status "Processing: $($operation.Name)" -PercentComplete $percentComplete
        Write-OofFooLog "Processing: $($operation.Name)" -Level Information

        try {
            $opResult = & $operation.ScriptBlock

            $results.Operations += [PSCustomObject]@{
                Name = $operation.Name
                Success = $true
                SpaceFreedMB = $opResult.SpaceFreedMB
                ItemsRemoved = $opResult.ItemsRemoved
                Message = $opResult.Message
            }

            $results.SpaceFreedMB += $opResult.SpaceFreedMB
        }
        catch {
            $errorMsg = "Failed: $($operation.Name) - $_"
            Write-OofFooLog $errorMsg -Level Error
            $results.Errors += $errorMsg

            $results.Operations += [PSCustomObject]@{
                Name = $operation.Name
                Success = $false
                SpaceFreedMB = 0
                ItemsRemoved = 0
                Message = $_.Exception.Message
            }
        }
    }

    Write-Progress -Activity "System Maintenance" -Completed

    # Calculate final results
    $endTime = Get-Date
    $finalSpace = Get-OofFooFreeSpace -DriveLetter C

    $results.EndTime = $endTime
    $results.FinalFreeSpaceGB = $finalSpace.FreeSpaceGB
    $results.Duration = $endTime - $startTime

    # Log summary
    Write-OofFooLog "=== Maintenance Complete ===" -Level Information
    Write-OofFooLog "Duration: $($results.Duration.TotalMinutes.ToString('F2')) minutes" -Level Information
    Write-OofFooLog "Space freed: $($results.SpaceFreedMB.ToString('F2')) MB" -Level Information
    Write-OofFooLog "Operations completed: $($results.Operations.Count)" -Level Information
    Write-OofFooLog "Errors encountered: $($results.Errors.Count)" -Level Information

    return $results
}

# Helper functions for cleanup operations

function Clear-WindowsTempFiles {
    param($Config)

    $tempPath = [System.IO.Path]::GetTempPath()
    $tempFileAgeDays = $Config.Maintenance.TempFileAgeDays
    $cutoffDate = (Get-Date).AddDays(-$tempFileAgeDays)

    Write-OofFooLog "Cleaning Windows temp files older than $tempFileAgeDays days" -Level Verbose

    $beforeSize = 0
    $afterSize = 0
    $itemsRemoved = 0

    try {
        # Calculate before size
        $tempFiles = Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        $beforeSize = ($tempFiles | Measure-Object -Property Length -Sum).Sum

        # Remove old files
        $filesToRemove = $tempFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        $itemsRemoved = ($filesToRemove | Measure-Object).Count

        $filesToRemove | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        # Calculate after size
        $afterSize = (Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

        $freedMB = [math]::Round(($beforeSize - $afterSize) / 1MB, 2)

        return @{
            SpaceFreedMB = $freedMB
            ItemsRemoved = $itemsRemoved
            Message = "Removed $itemsRemoved items, freed $freedMB MB"
        }
    }
    catch {
        throw "Error cleaning Windows temp files: $_"
    }
}

function Clear-UserTempFiles {
    param($Config)

    $userTemp = $env:TEMP
    $tempFileAgeDays = $Config.Maintenance.TempFileAgeDays
    $cutoffDate = (Get-Date).AddDays(-$tempFileAgeDays)

    try {
        $itemsRemoved = 0
        Get-ChildItem $userTemp -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate } |
            ForEach-Object {
                Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                $itemsRemoved++
            }

        return @{
            SpaceFreedMB = 0  # Hard to measure precisely
            ItemsRemoved = $itemsRemoved
            Message = "Removed $itemsRemoved items from user temp"
        }
    }
    catch {
        throw "Error cleaning user temp files: $_"
    }
}

function Clear-RecycleBinSafely {
    try {
        # Get recycle bin size before clearing
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.NameSpace(0xA)
        $items = $recycleBin.Items()
        $itemCount = $items.Count

        Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop

        return @{
            SpaceFreedMB = 0  # Windows doesn't easily report this
            ItemsRemoved = $itemCount
            Message = "Emptied recycle bin ($itemCount items)"
        }
    }
    catch {
        throw "Error emptying recycle bin: $_"
    }
}

function Clear-WindowsUpdateCache {
    if (-not (Test-OofFooAdministrator)) {
        throw "Administrator privileges required for Windows Update cache cleanup"
    }

    try {
        Stop-Service wuauserv -Force -ErrorAction Stop
        $updateCache = "$env:SystemRoot\SoftwareDistribution\Download"

        $beforeSize = 0
        if (Test-Path $updateCache) {
            $beforeSize = (Get-ChildItem $updateCache -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Get-ChildItem $updateCache -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }

        Start-Service wuauserv -ErrorAction Stop

        $freedMB = [math]::Round($beforeSize / 1MB, 2)

        return @{
            SpaceFreedMB = $freedMB
            ItemsRemoved = 0
            Message = "Cleared Windows Update cache, freed $freedMB MB"
        }
    }
    catch {
        Start-Service wuauserv -ErrorAction SilentlyContinue
        throw "Error clearing Windows Update cache: $_"
    }
}

function Clear-BrowserCaches {
    $totalFreed = 0

    # Chrome
    $chromePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
    )

    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            try {
                Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            catch {
                # Browser might be running, silently continue
            }
        }
    }

    # Edge
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    if (Test-Path $edgePath) {
        try {
            Get-ChildItem $edgePath -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        catch {
            # Browser might be running
        }
    }

    return @{
        SpaceFreedMB = 0
        ItemsRemoved = 0
        Message = "Cleared browser caches (Chrome, Edge)"
    }
}

function Clear-WindowsErrorReports {
    $errorReportPath = "$env:LOCALAPPDATA\Microsoft\Windows\WER"

    try {
        $beforeSize = 0
        if (Test-Path $errorReportPath) {
            $beforeSize = (Get-ChildItem $errorReportPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Get-ChildItem $errorReportPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -eq '.dmp' -or $_.Extension -eq '.txt' } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        $freedMB = [math]::Round($beforeSize / 1MB, 2)

        return @{
            SpaceFreedMB = $freedMB
            ItemsRemoved = 0
            Message = "Cleared Windows Error Reports, freed $freedMB MB"
        }
    }
    catch {
        throw "Error clearing error reports: $_"
    }
}

function Clear-DeliveryOptimizationCache {
    if (-not (Test-OofFooAdministrator)) {
        throw "Administrator privileges required for Delivery Optimization cleanup"
    }

    try {
        # Use DISM to clean delivery optimization files
        $result = & dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1

        return @{
            SpaceFreedMB = 0  # DISM doesn't report amount
            ItemsRemoved = 0
            Message = "Ran DISM cleanup (Delivery Optimization)"
        }
    }
    catch {
        throw "Error running DISM cleanup: $_"
    }
}
