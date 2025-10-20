<#
.SYNOPSIS
    Build script for oof-foo

.DESCRIPTION
    Builds, tests, analyzes, and packages the oof-foo PowerShell module

.PARAMETER Clean
    Clean build artifacts before building

.PARAMETER Analyze
    Run PSScriptAnalyzer code analysis

.PARAMETER Test
    Run tests after building

.PARAMETER Package
    Create distribution package

.EXAMPLE
    .\Build.ps1 -Clean -Analyze -Test -Package
#>

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$Analyze,
    [switch]$Test,
    [switch]$Package
)

$ErrorActionPreference = 'Stop'

# Paths
$projectRoot = Split-Path -Parent $PSScriptRoot
$srcPath = Join-Path $projectRoot "src"
$buildOutputPath = Join-Path $PSScriptRoot "output"
$testsPath = Join-Path $projectRoot "tests"

Write-Host ""
Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         oof-foo Build Script              ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "Project Root: $projectRoot`n" -ForegroundColor Cyan

# Clean
if ($Clean) {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    if (Test-Path $buildOutputPath) {
        Remove-Item $buildOutputPath -Recurse -Force
        Write-Host "✓ Build output cleaned`n" -ForegroundColor Green
    }
}

# Create output directory
if (-not (Test-Path $buildOutputPath)) {
    New-Item -Path $buildOutputPath -ItemType Directory | Out-Null
}

# Validate module
Write-Host "Validating module..." -ForegroundColor Cyan
$manifestPath = Join-Path $srcPath "OofFoo\OofFoo.psd1"

if (-not (Test-Path $manifestPath)) {
    Write-Error "Module manifest not found: $manifestPath"
    exit 1
}

try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    Write-Host "✓ Module validation passed" -ForegroundColor Green
    Write-Host "  Name:    $($manifest.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
    Write-Host "  Author:  $($manifest.Author)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Error "Module validation failed: $_"
    exit 1
}

# Run PSScriptAnalyzer
if ($Analyze) {
    Write-Host "Running PSScriptAnalyzer..." -ForegroundColor Cyan

    # Check if PSScriptAnalyzer is installed
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Warning "PSScriptAnalyzer not installed. Installing..."
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -SkipPublisherCheck
    }

    Import-Module PSScriptAnalyzer

    $analysisResults = Invoke-ScriptAnalyzer -Path (Join-Path $srcPath "OofFoo") -Recurse -ReportSummary

    if ($analysisResults) {
        Write-Host "`nCode Analysis Results:" -ForegroundColor Yellow
        $analysisResults | Format-Table -Property Severity, RuleName, ScriptName, Line, Message -AutoSize

        $errorCount = ($analysisResults | Where-Object { $_.Severity -eq 'Error' }).Count
        $warningCount = ($analysisResults | Where-Object { $_.Severity -eq 'Warning' }).Count
        $infoCount = ($analysisResults | Where-Object { $_.Severity -eq 'Information' }).Count

        Write-Host "`nSummary:" -ForegroundColor Cyan
        Write-Host "  Errors:   $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
        Write-Host "  Warnings: $warningCount" -ForegroundColor $(if ($warningCount -gt 0) { "Yellow" } else { "Green" })
        Write-Host "  Info:     $infoCount" -ForegroundColor Gray

        if ($errorCount -gt 0) {
            Write-Error "PSScriptAnalyzer found $errorCount error(s). Build failed."
            exit 1
        }

        Write-Host ""
    }
    else {
        Write-Host "✓ No issues found!`n" -ForegroundColor Green
    }
}

# Run tests
if ($Test) {
    Write-Host "Running tests..." -ForegroundColor Cyan

    # Check if Pester is installed
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Warning "Pester not installed. Installing..."
        Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck -MinimumVersion 5.0
    }

    if (Test-Path $testsPath) {
        Import-Module Pester

        $config = New-PesterConfiguration
        $config.Run.Path = $testsPath
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Detailed'

        $testResults = Invoke-Pester -Configuration $config

        if ($testResults.FailedCount -gt 0) {
            Write-Error "Tests failed: $($testResults.FailedCount) test(s) failed"
            exit 1
        }

        Write-Host "✓ All tests passed!`n" -ForegroundColor Green
        Write-Host "  Passed: $($testResults.PassedCount)" -ForegroundColor Green
        Write-Host "  Failed: $($testResults.FailedCount)" -ForegroundColor Green
        Write-Host "  Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        Write-Warning "No tests directory found at: $testsPath"
    }
}

# Package
if ($Package) {
    Write-Host "Creating distribution package..." -ForegroundColor Cyan

    $version = $manifest.Version.ToString()
    $packageName = "oof-foo-v$version"
    $packagePath = Join-Path $buildOutputPath $packageName

    # Create package directory
    if (Test-Path $packagePath) {
        Remove-Item $packagePath -Recurse -Force
    }
    New-Item -Path $packagePath -ItemType Directory | Out-Null

    # Copy files
    Write-Host "Copying files..." -ForegroundColor Gray

    # Copy module
    $moduleDestination = Join-Path $packagePath "src\OofFoo"
    Copy-Item -Path (Join-Path $srcPath "OofFoo") -Destination $moduleDestination -Recurse -Force

    # Copy launcher
    Copy-Item -Path (Join-Path $projectRoot "oof-foo.ps1") -Destination $packagePath -Force

    # Copy README and docs
    Copy-Item -Path (Join-Path $projectRoot "README.md") -Destination $packagePath -Force
    Copy-Item -Path (Join-Path $projectRoot "LICENSE") -Destination $packagePath -Force
    Copy-Item -Path (Join-Path $projectRoot "CHANGELOG.md") -Destination $packagePath -Force

    # Create installation script
    $installScript = @"
# oof-foo Installation Script

Write-Host ""
Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     Installing oof-foo...                ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Check PowerShell version
if (`$PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "PowerShell 5.1 or later is required"
    exit 1
}

# Get installation directory
`$modulePath = `$env:PSModulePath -split ';' | Where-Object { `$_ -like "*Documents*" } | Select-Object -First 1
`$installPath = Join-Path `$modulePath "OofFoo"

# Create directory if it doesn't exist
if (-not (Test-Path `$installPath)) {
    New-Item -Path `$installPath -ItemType Directory -Force | Out-Null
}

# Copy module files
Write-Host "Copying module files to: `$installPath" -ForegroundColor Cyan
Copy-Item -Path ".\src\OofFoo\*" -Destination `$installPath -Recurse -Force

# Create desktop shortcut
`$desktopPath = [Environment]::GetFolderPath("Desktop")
`$shortcutPath = Join-Path `$desktopPath "oof-foo.lnk"

`$WScriptShell = New-Object -ComObject WScript.Shell
`$shortcut = `$WScriptShell.CreateShortcut(`$shortcutPath)
`$shortcut.TargetPath = "powershell.exe"
`$shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -Command `"Import-Module OofFoo; Start-OofFooGUI`""
`$shortcut.IconLocation = "powershell.exe,0"
`$shortcut.Description = "oof-foo - System Maintenance Tool"
`$shortcut.Save()

Write-Host ""
Write-Host "✓ Installation complete!" -ForegroundColor Green
Write-Host "  Module installed to: `$installPath" -ForegroundColor Cyan
Write-Host "  Desktop shortcut created" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now run:" -ForegroundColor Yellow
Write-Host "  Import-Module OofFoo" -ForegroundColor Gray
Write-Host "  Start-OofFooGUI" -ForegroundColor Gray
Write-Host ""
Write-Host "Or use the desktop shortcut!`n" -ForegroundColor Green
"@

    $installScript | Out-File -FilePath (Join-Path $packagePath "Install.ps1") -Encoding UTF8

    # Create README for package
    $packageReadme = @"
# oof-foo v$version

From "oof" to "phew!" - System maintenance made easy

## Quick Start

1. Run Install.ps1 to install the module
2. Use the desktop shortcut or run: Start-OofFooGUI

## Manual Installation

``````powershell
# Import the module
Import-Module .\src\OofFoo\OofFoo.psd1

# Launch GUI
Start-OofFooGUI
``````

## Documentation

See README.md for full documentation.

---

https://oof.foo
"@

    $packageReadme | Out-File -FilePath (Join-Path $packagePath "INSTALL.txt") -Encoding UTF8

    # Create ZIP archive
    $zipPath = Join-Path $buildOutputPath "$packageName.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Write-Host "Creating ZIP archive..." -ForegroundColor Gray
    Compress-Archive -Path "$packagePath\*" -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host "✓ Package created: $zipPath" -ForegroundColor Green
    Write-Host "  Size: $([math]::Round((Get-Item $zipPath).Length / 1KB, 2)) KB`n" -ForegroundColor Cyan
}

Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
Write-Host "Output directory: $buildOutputPath`n" -ForegroundColor Cyan
