<#
.SYNOPSIS
    oof-foo - All-in-one Windows system maintenance tool

.DESCRIPTION
    Main launcher script for the oof-foo system maintenance application.
    From "oof" to "phew!" - System maintenance made easy.

.PARAMETER GUI
    Launch the graphical user interface (default)

.PARAMETER Update
    Run system updates only

.PARAMETER Maintenance
    Run system maintenance only

.PARAMETER Patch
    Run security patching only

.PARAMETER HealthCheck
    Run system health check

.PARAMETER Full
    Run full maintenance suite (updates, patches, and cleanup)

.EXAMPLE
    .\oof-foo.ps1
    Launches the GUI

.EXAMPLE
    .\oof-foo.ps1 -Full
    Runs complete maintenance from command line

.EXAMPLE
    .\oof-foo.ps1 -HealthCheck
    Generates a system health report

.NOTES
    Requires PowerShell 5.1 or later
    Administrator privileges recommended for most operations
    Version: 0.1.0
#>

[CmdletBinding(DefaultParameterSetName = 'GUI')]
param(
    [Parameter(ParameterSetName = 'GUI')]
    [switch]$GUI,

    [Parameter(ParameterSetName = 'Update')]
    [switch]$Update,

    [Parameter(ParameterSetName = 'Maintenance')]
    [switch]$Maintenance,

    [Parameter(ParameterSetName = 'Patch')]
    [switch]$Patch,

    [Parameter(ParameterSetName = 'HealthCheck')]
    [switch]$HealthCheck,

    [Parameter(ParameterSetName = 'Full')]
    [switch]$Full
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Banner
$banner = @"

    ╔═══════════════════════════════════════════╗
    ║                                           ║
    ║           oof-foo (00FF00)                ║
    ║                                           ║
    ║   From "oof" to "phew!" in one click!    ║
    ║                                           ║
    ╚═══════════════════════════════════════════╝

"@

Write-Host $banner -ForegroundColor Green

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "PowerShell 5.1 or later is required. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Check for admin privileges (warn but don't block)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "oof-foo is running without administrator privileges."
    Write-Warning "Some features may not work correctly."
    Write-Host "Consider running as administrator for full functionality.`n" -ForegroundColor Yellow
}

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptPath "src\OofFoo\OofFoo.psd1"

# Import the module
Write-Host "Loading oof-foo module..." -ForegroundColor Cyan

if (Test-Path $modulePath) {
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "Module loaded successfully!`n" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to load oof-foo module: $_"
        exit 1
    }
}
else {
    Write-Error "oof-foo module not found at: $modulePath"
    Write-Error "Please ensure the project structure is intact."
    exit 1
}

# Execute based on parameters
try {
    switch ($PSCmdlet.ParameterSetName) {
        'GUI' {
            Write-Host "Launching GUI...`n" -ForegroundColor Green
            Start-OofFooGUI
        }

        'Update' {
            Write-Host "Running system updates...`n" -ForegroundColor Green
            Invoke-SystemUpdate -UpdateType All
        }

        'Maintenance' {
            Write-Host "Running system maintenance...`n" -ForegroundColor Green
            Invoke-SystemMaintenance -DeepClean
        }

        'Patch' {
            Write-Host "Running security patches...`n" -ForegroundColor Green
            Invoke-SystemPatch -IncludeThirdParty
        }

        'HealthCheck' {
            Write-Host "Running health check...`n" -ForegroundColor Green
            $report = Get-SystemHealth -Detailed

            # Display summary
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "SYSTEM HEALTH REPORT" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Timestamp: $($report.Timestamp)" -ForegroundColor White
            Write-Host "Overall Health: $($report.OverallHealth)" -ForegroundColor $(
                if ($report.OverallHealth -eq "Good") { "Green" }
                elseif ($report.OverallHealth -eq "Fair") { "Yellow" }
                else { "Red" }
            )

            if ($report.Warnings.Count -gt 0) {
                Write-Host "`nWarnings:" -ForegroundColor Yellow
                $report.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
            }

            Write-Host "`nFor detailed report, use: Get-SystemHealth -Detailed | Format-List" -ForegroundColor Gray
        }

        'Full' {
            Write-Host "Running FULL maintenance suite...`n" -ForegroundColor Green
            Write-Host "This may take several minutes. Please be patient.`n" -ForegroundColor Yellow

            # Health check first
            Write-Host "Step 1: Pre-maintenance health check" -ForegroundColor Cyan
            $beforeHealth = Get-SystemHealth

            # Updates
            Write-Host "`nStep 2: System updates" -ForegroundColor Cyan
            Invoke-SystemUpdate -UpdateType All

            # Security patches
            Write-Host "`nStep 3: Security patches" -ForegroundColor Cyan
            Invoke-SystemPatch -IncludeThirdParty

            # Maintenance
            Write-Host "`nStep 4: System cleanup and maintenance" -ForegroundColor Cyan
            Invoke-SystemMaintenance -DeepClean -IncludeLogs

            # Final health check
            Write-Host "`nStep 5: Post-maintenance health check" -ForegroundColor Cyan
            $afterHealth = Get-SystemHealth

            Write-Host "`n========================================" -ForegroundColor Green
            Write-Host "FULL MAINTENANCE COMPLETE!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "From 'oof' to 'phew!' - Your system is refreshed!`n" -ForegroundColor Green

            # Show improvement
            Write-Host "Health Status:" -ForegroundColor Cyan
            Write-Host "  Before: $($beforeHealth.OverallHealth)" -ForegroundColor Yellow
            Write-Host "  After:  $($afterHealth.OverallHealth)" -ForegroundColor Green
        }

        Default {
            # Default to GUI
            Write-Host "Launching GUI...`n" -ForegroundColor Green
            Start-OofFooGUI
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
    Write-Host "`nFor help, run: Get-Help .\oof-foo.ps1 -Full" -ForegroundColor Yellow
    exit 1
}

Write-Host "`noof-foo session complete. Thank you for using oof.foo!" -ForegroundColor Green
