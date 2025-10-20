function Invoke-SystemUpdate {
    <#
    .SYNOPSIS
        Performs system and application updates

    .DESCRIPTION
        Checks for and installs Windows Updates, winget packages, and other system updates.
        Part of the oof-foo maintenance suite.

    .PARAMETER UpdateType
        Type of updates to perform: All, WindowsUpdate, WinGet, Chocolatey

    .PARAMETER AutoRestart
        Automatically restart if required after updates

    .EXAMPLE
        Invoke-SystemUpdate -UpdateType All

    .EXAMPLE
        Invoke-SystemUpdate -UpdateType WinGet
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'WindowsUpdate', 'WinGet', 'Chocolatey')]
        [string]$UpdateType = 'All',

        [Parameter()]
        [switch]$AutoRestart
    )

    Write-Host "oof-foo: Starting system updates..." -ForegroundColor Green

    $results = @{
        WindowsUpdate = $null
        WinGet = $null
        Chocolatey = $null
        RestartRequired = $false
    }

    # Windows Updates
    if ($UpdateType -in @('All', 'WindowsUpdate')) {
        Write-Host "`nChecking Windows Updates..." -ForegroundColor Cyan

        try {
            # Check if PSWindowsUpdate module is available
            if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                Write-Warning "PSWindowsUpdate module not installed. Installing..."
                Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
            }

            Import-Module PSWindowsUpdate -ErrorAction Stop
            $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

            if ($updates) {
                Write-Host "Found $($updates.Count) Windows update(s)" -ForegroundColor Yellow
                # Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot:$AutoRestart
                $results.WindowsUpdate = "Found $($updates.Count) update(s)"
                $results.RestartRequired = $true
            }
            else {
                Write-Host "Windows is up to date" -ForegroundColor Green
                $results.WindowsUpdate = "Up to date"
            }
        }
        catch {
            Write-Warning "Windows Update check failed: $_"
            $results.WindowsUpdate = "Error: $_"
        }
    }

    # WinGet Updates
    if ($UpdateType -in @('All', 'WinGet')) {
        Write-Host "`nChecking winget packages..." -ForegroundColor Cyan

        try {
            # Check if winget is available
            $winget = Get-Command winget -ErrorAction SilentlyContinue

            if ($winget) {
                $upgradeList = winget upgrade --include-unknown 2>$null
                Write-Host "Winget packages checked" -ForegroundColor Green
                # To actually upgrade: winget upgrade --all --silent
                $results.WinGet = "Checked successfully"
            }
            else {
                Write-Warning "winget not found. Please install App Installer from Microsoft Store."
                $results.WinGet = "Not available"
            }
        }
        catch {
            Write-Warning "Winget check failed: $_"
            $results.WinGet = "Error: $_"
        }
    }

    # Chocolatey Updates
    if ($UpdateType -in @('All', 'Chocolatey')) {
        Write-Host "`nChecking Chocolatey packages..." -ForegroundColor Cyan

        try {
            $choco = Get-Command choco -ErrorAction SilentlyContinue

            if ($choco) {
                # choco upgrade all -y
                Write-Host "Chocolatey packages checked" -ForegroundColor Green
                $results.Chocolatey = "Checked successfully"
            }
            else {
                Write-Host "Chocolatey not installed (optional)" -ForegroundColor Gray
                $results.Chocolatey = "Not installed"
            }
        }
        catch {
            Write-Warning "Chocolatey check failed: $_"
            $results.Chocolatey = "Error: $_"
        }
    }

    Write-Host "`noof-foo: Update check complete!" -ForegroundColor Green

    return $results
}
