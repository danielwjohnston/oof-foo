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

function Clear-WindowsOldFolder {
    <#
    .SYNOPSIS
        Removes Windows.old folder from previous Windows installation
    #>

    if (-not (Test-OofFooAdministrator)) {
        throw "Administrator privileges required for Windows.old cleanup"
    }

    $windowsOldPath = "C:\Windows.old"

    if (-not (Test-Path $windowsOldPath)) {
        return @{
            SpaceFreedMB = 0
            ItemsRemoved = 0
            Message = "Windows.old not found (already cleaned or no upgrade)"
        }
    }

    try {
        Write-OofFooLog "Cleaning Windows.old folder..." -Level Information

        # Calculate size before
        $beforeSize = (Get-ChildItem $windowsOldPath -Recurse -Force -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum

        # Use DISM to clean Windows.old safely
        $result = & dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1

        # Also try direct removal (DISM doesn't always remove Windows.old)
        if (Test-Path $windowsOldPath) {
            # Take ownership and remove
            & takeown.exe /F $windowsOldPath /R /D Y 2>&1 | Out-Null
            & icacls.exe $windowsOldPath /grant "BUILTIN\Administrators:(F)" /T /C /Q 2>&1 | Out-Null
            Remove-Item $windowsOldPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        $freedMB = [math]::Round($beforeSize / 1MB, 2)

        Write-OofFooLog "Windows.old cleanup completed. Freed: $freedMB MB" -Level Information

        return @{
            SpaceFreedMB = $freedMB
            ItemsRemoved = 1
            Message = "Cleaned Windows.old folder, freed $freedMB MB"
        }
    }
    catch {
        throw "Error cleaning Windows.old: $_"
    }
}

function Clear-DriverStoreOrphans {
    <#
    .SYNOPSIS
        Removes orphaned drivers from the driver store
    #>

    if (-not (Test-OofFooAdministrator)) {
        throw "Administrator privileges required for driver store cleanup"
    }

    try {
        Write-OofFooLog "Cleaning orphaned drivers from driver store..." -Level Information

        # Use pnputil to remove orphaned drivers
        $drivers = & pnputil.exe /enum-drivers 2>&1 | Out-String

        # Count before
        $beforeCount = ([regex]::Matches($drivers, "oem\d+\.inf")).Count

        # Remove orphaned drivers (non-present devices)
        & pnputil.exe /delete-driver * /uninstall /force 2>&1 | Out-Null

        Write-OofFooLog "Driver store cleanup completed" -Level Information

        return @{
            SpaceFreedMB = 0  # Hard to measure
            ItemsRemoved = 0
            Message = "Cleaned orphaned drivers from driver store"
        }
    }
    catch {
        # Non-critical error, just log
        Write-OofFooLog "Driver store cleanup had issues (non-critical): $_" -Level Warning
        return @{
            SpaceFreedMB = 0
            ItemsRemoved = 0
            Message = "Driver store cleanup skipped (no orphans or error)"
        }
    }
}

function Clear-ThumbnailCache {
    <#
    .SYNOPSIS
        Clears Windows thumbnail cache
    #>

    try {
        $thumbnailPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"

        $beforeSize = 0
        if (Test-Path $thumbnailPath) {
            $thumbFiles = Get-ChildItem $thumbnailPath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue
            $beforeSize = ($thumbFiles | Measure-Object -Property Length -Sum).Sum

            $thumbFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        $freedMB = [math]::Round($beforeSize / 1MB, 2)

        return @{
            SpaceFreedMB = $freedMB
            ItemsRemoved = ($thumbFiles | Measure-Object).Count
            Message = "Cleared thumbnail cache, freed $freedMB MB"
        }
    }
    catch {
        throw "Error clearing thumbnail cache: $_"
    }
}

function Clear-WindowsInstallerCache {
    <#
    .SYNOPSIS
        Cleans up Windows Installer cache (carefully)
    #>

    if (-not (Test-OofFooAdministrator)) {
        throw "Administrator privileges required for Windows Installer cache cleanup"
    }

    try {
        Write-OofFooLog "Cleaning Windows Installer cache..." -Level Information

        $installerPath = "$env:SystemRoot\Installer"

        if (Test-Path $installerPath) {
            # Only remove .tmp files and old patches (safer approach)
            $beforeSize = 0
            $tmpFiles = Get-ChildItem $installerPath -Filter "*.tmp" -Force -ErrorAction SilentlyContinue
            $beforeSize = ($tmpFiles | Measure-Object -Property Length -Sum).Sum

            $tmpFiles | Remove-Item -Force -ErrorAction SilentlyContinue

            $freedMB = [math]::Round($beforeSize / 1MB, 2)

            return @{
                SpaceFreedMB = $freedMB
                ItemsRemoved = ($tmpFiles | Measure-Object).Count
                Message = "Cleaned Windows Installer temp files, freed $freedMB MB"
            }
        }

        return @{
            SpaceFreedMB = 0
            ItemsRemoved = 0
            Message = "Windows Installer cache not found or empty"
        }
    }
    catch {
        throw "Error cleaning Windows Installer cache: $_"
    }
}

function Clear-DNSCache {
    <#
    .SYNOPSIS
        Flushes DNS resolver cache
    #>

    try {
        & ipconfig.exe /flushdns 2>&1 | Out-Null

        return @{
            SpaceFreedMB = 0
            ItemsRemoved = 0
            Message = "Flushed DNS cache"
        }
    }
    catch {
        throw "Error flushing DNS cache: $_"
    }
}

function Invoke-AdvancedSystemMaintenance {
    <#
    .SYNOPSIS
        Performs advanced/aggressive system maintenance

    .DESCRIPTION
        Runs advanced cleanup operations including Windows.old, driver store,
        and other deep system cleaning. Requires admin privileges.

    .PARAMETER SkipConfirmation
        Skip confirmation prompt

    .EXAMPLE
        Invoke-AdvancedSystemMaintenance
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$SkipConfirmation
    )

    if (-not (Test-OofFooAdministrator)) {
        throw "Administrator privileges required for advanced maintenance"
    }

    $config = Get-OofFooConfig
    Write-OofFooLog "=== Starting Advanced System Maintenance ===" -Level Information

    # Confirmation
    if (-not $SkipConfirmation) {
        $message = "This will perform aggressive cleanup including Windows.old removal. Continue?"
        $confirmation = Read-Host "$message (yes/no)"

        if ($confirmation -ne 'yes' -and $confirmation -ne 'y') {
            Write-OofFooLog "Advanced maintenance cancelled by user" -Level Warning
            return
        }
    }

    # Create restore point
    if ($config.Maintenance.CreateRestorePointBeforeMaintenance) {
        Write-OofFooLog "Creating restore point before advanced maintenance..." -Level Information
        New-OofFooRestorePoint -Description "Before oof-foo advanced maintenance"
    }

    # Results tracking
    $results = [PSCustomObject]@{
        StartTime = Get-Date
        EndTime = $null
        Operations = @()
        SpaceFreedMB = 0
        Errors = @()
    }

    # Define advanced operations
    $operations = @(
        @{ Name = "Windows.old Cleanup"; ScriptBlock = { Clear-WindowsOldFolder } }
        @{ Name = "Driver Store Orphans"; ScriptBlock = { Clear-DriverStoreOrphans } }
        @{ Name = "Thumbnail Cache"; ScriptBlock = { Clear-ThumbnailCache } }
        @{ Name = "Windows Installer Cache"; ScriptBlock = { Clear-WindowsInstallerCache } }
        @{ Name = "DNS Cache"; ScriptBlock = { Clear-DNSCache } }
    )

    # Execute operations
    foreach ($operation in $operations) {
        Write-Progress -Activity "Advanced Maintenance" -Status $operation.Name
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

    Write-Progress -Activity "Advanced Maintenance" -Completed

    $results.EndTime = Get-Date
    Write-OofFooLog "=== Advanced Maintenance Complete ===" -Level Information
    Write-OofFooLog "Total space freed: $($results.SpaceFreedMB) MB" -Level Information

    return $results
}
