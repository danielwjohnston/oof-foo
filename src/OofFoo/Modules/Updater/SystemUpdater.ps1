function Invoke-SystemUpdate {
    <#
    .SYNOPSIS
        Performs system and application updates

    .DESCRIPTION
        Checks for and installs Windows Updates, winget packages, and other system updates.
        Part of the oof-foo maintenance suite. Uses logging and configuration.

    .PARAMETER UpdateType
        Type of updates to perform: All, WindowsUpdate, WinGet, Chocolatey

    .PARAMETER AutoRestart
        Automatically restart if required after updates

    .PARAMETER DownloadOnly
        Download updates but don't install them

    .PARAMETER SkipConfirmation
        Skip confirmation prompts

    .EXAMPLE
        Invoke-SystemUpdate -UpdateType All

    .EXAMPLE
        Invoke-SystemUpdate -UpdateType WinGet -DownloadOnly
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'WindowsUpdate', 'WinGet', 'Chocolatey')]
        [string]$UpdateType = 'All',

        [Parameter()]
        [switch]$AutoRestart,

        [Parameter()]
        [switch]$DownloadOnly,

        [Parameter()]
        [switch]$SkipConfirmation
    )

    $config = Get-OofFooConfig
    Write-OofFooLog "=== Starting System Updates ===" -Level Information
    Write-OofFooLog "Update Type: $UpdateType" -Level Information

    # Check internet connectivity
    if (-not (Test-OofFooOnline)) {
        Write-OofFooLog "No internet connection detected" -Level Error
        throw "Internet connection required for updates"
    }

    # Results tracking
    $results = [PSCustomObject]@{
        StartTime = Get-Date
        EndTime = $null
        WindowsUpdate = $null
        WinGet = $null
        Chocolatey = $null
        RestartRequired = $false
        Success = $true
        Errors = @()
    }

    # Confirmation check
    if (-not $SkipConfirmation -and -not $DownloadOnly) {
        $message = "This will download and install system updates. This may take some time. Continue?"
        $confirmation = Read-Host "$message (yes/no)"

        if ($confirmation -ne 'yes' -and $confirmation -ne 'y') {
            Write-OofFooLog "Updates cancelled by user" -Level Warning
            $results.Success = $false
            return $results
        }
    }

    # Windows Updates
    if ($UpdateType -in @('All', 'WindowsUpdate') -and $config.Updates.CheckWindowsUpdate) {
        Write-OofFooLog "Checking Windows Updates..." -Level Information
        Write-Progress -Activity "System Updates" -Status "Processing Windows Update" -PercentComplete 10

        try {
            $winUpdateResult = Invoke-WindowsUpdateCheck -DownloadOnly:$DownloadOnly -AutoRestart:$AutoRestart
            $results.WindowsUpdate = $winUpdateResult
            if ($winUpdateResult.RestartRequired) {
                $results.RestartRequired = $true
            }
        }
        catch {
            $errorMsg = "Windows Update failed: $_"
            Write-OofFooLog $errorMsg -Level Error
            $results.Errors += $errorMsg
            $results.WindowsUpdate = [PSCustomObject]@{
                Status = "Error"
                Message = $_.Exception.Message
            }
        }
    }

    # WinGet Updates
    if ($UpdateType -in @('All', 'WinGet') -and $config.Updates.CheckWinGet) {
        Write-OofFooLog "Checking winget packages..." -Level Information
        Write-Progress -Activity "System Updates" -Status "Processing winget packages" -PercentComplete 50

        try {
            $wingetResult = Invoke-WinGetUpdate -DownloadOnly:$DownloadOnly
            $results.WinGet = $wingetResult
        }
        catch {
            $errorMsg = "WinGet update failed: $_"
            Write-OofFooLog $errorMsg -Level Error
            $results.Errors += $errorMsg
            $results.WinGet = [PSCustomObject]@{
                Status = "Error"
                Message = $_.Exception.Message
            }
        }
    }

    # Chocolatey Updates
    if ($UpdateType -in @('All', 'Chocolatey') -and $config.Updates.CheckChocolatey) {
        Write-OofFooLog "Checking Chocolatey packages..." -Level Information
        Write-Progress -Activity "System Updates" -Status "Processing Chocolatey packages" -PercentComplete 80

        try {
            $chocoResult = Invoke-ChocolateyUpdate -DownloadOnly:$DownloadOnly
            $results.Chocolatey = $chocoResult
        }
        catch {
            $errorMsg = "Chocolatey update failed: $_"
            Write-OofFooLog $errorMsg -Level Error
            $results.Errors += $errorMsg
            $results.Chocolatey = [PSCustomObject]@{
                Status = "Error"
                Message = $_.Exception.Message
            }
        }
    }

    Write-Progress -Activity "System Updates" -Completed

    $results.EndTime = Get-Date
    Write-OofFooLog "=== System Updates Complete ===" -Level Information

    if ($results.RestartRequired) {
        Write-OofFooLog "RESTART REQUIRED to complete updates" -Level Warning
    }

    return $results
}

# Helper functions

function Invoke-WindowsUpdateCheck {
    param(
        [switch]$DownloadOnly,
        [switch]$AutoRestart
    )

    # Check if PSWindowsUpdate module is available
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-OofFooLog "PSWindowsUpdate module not found. Installing..." -Level Warning

        try {
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            Write-OofFooLog "PSWindowsUpdate module installed successfully" -Level Information
        }
        catch {
            throw "Failed to install PSWindowsUpdate module: $_"
        }
    }

    Import-Module PSWindowsUpdate -ErrorAction Stop

    # Get available updates
    Write-OofFooLog "Scanning for Windows updates..." -Level Information
    $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

    $updateCount = ($updates | Measure-Object).Count
    Write-OofFooLog "Found $updateCount Windows update(s)" -Level Information

    if ($updateCount -eq 0) {
        return [PSCustomObject]@{
            Status = "UpToDate"
            UpdatesFound = 0
            UpdatesInstalled = 0
            RestartRequired = $false
            Message = "Windows is up to date"
        }
    }

    # List updates
    foreach ($update in $updates) {
        $severity = if ($update.MsrcSeverity) { $update.MsrcSeverity } else { "Normal" }
        Write-OofFooLog "  - $($update.Title) [$severity]" -Level Information
    }

    if ($DownloadOnly) {
        Write-OofFooLog "Downloading updates only (not installing)..." -Level Information
        $installed = Get-WindowsUpdate -MicrosoftUpdate -Download -AcceptAll

        return [PSCustomObject]@{
            Status = "Downloaded"
            UpdatesFound = $updateCount
            UpdatesInstalled = 0
            RestartRequired = $false
            Message = "Downloaded $updateCount update(s)"
        }
    }

    # Install updates
    Write-OofFooLog "Installing Windows updates..." -Level Information
    $installParams = @{
        MicrosoftUpdate = $true
        AcceptAll = $true
        IgnoreReboot = $true
        ErrorAction = 'Stop'
    }

    $installed = Install-WindowsUpdate @installParams

    $installedCount = ($installed | Measure-Object).Count
    $rebootRequired = ($installed | Where-Object { $_.RebootRequired }).Count -gt 0

    Write-OofFooLog "Installed $installedCount update(s)" -Level Information

    if ($rebootRequired) {
        Write-OofFooLog "Restart required to complete installation" -Level Warning

        if ($AutoRestart) {
            Write-OofFooLog "Auto-restart enabled, scheduling restart..." -Level Warning
            shutdown /r /t 300 /c "oof-foo: Restarting in 5 minutes to complete updates"
        }
    }

    return [PSCustomObject]@{
        Status = "Installed"
        UpdatesFound = $updateCount
        UpdatesInstalled = $installedCount
        RestartRequired = $rebootRequired
        Message = "Installed $installedCount update(s)"
        Updates = $installed
    }
}

function Invoke-WinGetUpdate {
    param([switch]$DownloadOnly)

    # Check if winget is available
    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $winget) {
        Write-OofFooLog "winget not found. Please install App Installer from Microsoft Store." -Level Warning
        return [PSCustomObject]@{
            Status = "NotAvailable"
            Message = "winget not installed"
        }
    }

    # Get upgrade list
    Write-OofFooLog "Checking for winget package updates..." -Level Information
    $upgradeList = winget upgrade 2>&1

    # Parse output to count available updates
    $upgradeLines = $upgradeList | Where-Object { $_ -match '^\S+\s+\S+' -and $_ -notmatch '^Name' -and $_ -notmatch 'upgrades available' }
    $upgradeCount = ($upgradeLines | Measure-Object).Count

    Write-OofFooLog "Found $upgradeCount winget package(s) with updates available" -Level Information

    if ($upgradeCount -eq 0) {
        return [PSCustomObject]@{
            Status = "UpToDate"
            UpdatesAvailable = 0
            UpdatesInstalled = 0
            Message = "All winget packages are up to date"
        }
    }

    if ($DownloadOnly) {
        Write-OofFooLog "Download-only mode not supported for winget" -Level Warning
        return [PSCustomObject]@{
            Status = "Skipped"
            UpdatesAvailable = $upgradeCount
            UpdatesInstalled = 0
            Message = "Download-only not supported for winget"
        }
    }

    # Upgrade all packages
    Write-OofFooLog "Upgrading winget packages..." -Level Information
    $upgradeResult = winget upgrade --all --silent --accept-source-agreements --accept-package-agreements 2>&1

    return [PSCustomObject]@{
        Status = "Completed"
        UpdatesAvailable = $upgradeCount
        UpdatesInstalled = $upgradeCount
        Message = "Upgraded $upgradeCount winget package(s)"
        Output = $upgradeResult
    }
}

function Invoke-ChocolateyUpdate {
    param([switch]$DownloadOnly)

    # Check if Chocolatey is installed
    $choco = Get-Command choco -ErrorAction SilentlyContinue

    if (-not $choco) {
        Write-OofFooLog "Chocolatey not installed (optional)" -Level Information
        return [PSCustomObject]@{
            Status = "NotInstalled"
            Message = "Chocolatey not installed"
        }
    }

    # Get outdated packages
    Write-OofFooLog "Checking for Chocolatey package updates..." -Level Information
    $outdated = choco outdated --limit-output 2>&1

    $outdatedCount = ($outdated | Where-Object { $_ -match '\|' } | Measure-Object).Count
    Write-OofFooLog "Found $outdatedCount Chocolatey package(s) with updates available" -Level Information

    if ($outdatedCount -eq 0) {
        return [PSCustomObject]@{
            Status = "UpToDate"
            UpdatesAvailable = 0
            UpdatesInstalled = 0
            Message = "All Chocolatey packages are up to date"
        }
    }

    if ($DownloadOnly) {
        Write-OofFooLog "Download-only mode not well supported for Chocolatey" -Level Warning
        return [PSCustomObject]@{
            Status = "Skipped"
            UpdatesAvailable = $outdatedCount
            UpdatesInstalled = 0
            Message = "Download-only not supported for Chocolatey"
        }
    }

    # Upgrade all packages
    Write-OofFooLog "Upgrading Chocolatey packages..." -Level Information
    $upgradeResult = choco upgrade all -y 2>&1

    return [PSCustomObject]@{
        Status = "Completed"
        UpdatesAvailable = $outdatedCount
        UpdatesInstalled = $outdatedCount
        Message = "Upgraded $outdatedCount Chocolatey package(s)"
        Output = $upgradeResult
    }
}
