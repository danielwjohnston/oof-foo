<#
.SYNOPSIS
    Build script for oof-foo

.DESCRIPTION
    Builds, tests, and packages the oof-foo PowerShell module

.PARAMETER Clean
    Clean build artifacts before building

.PARAMETER Test
    Run tests after building

.PARAMETER Package
    Create distribution package

.EXAMPLE
    .\Build.ps1 -Clean -Test -Package
#>

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$Test,
    [switch]$Package
)

$ErrorActionPreference = 'Stop'

# Paths
$projectRoot = Split-Path -Parent $PSScriptRoot
$srcPath = Join-Path $projectRoot "src"
$buildOutputPath = Join-Path $PSScriptRoot "output"
$testsPath = Join-Path $projectRoot "tests"

Write-Host "oof-foo Build Script" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host "Project Root: $projectRoot`n" -ForegroundColor Cyan

# Clean
if ($Clean) {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    if (Test-Path $buildOutputPath) {
        Remove-Item $buildOutputPath -Recurse -Force
        Write-Host "Build output cleaned`n" -ForegroundColor Green
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
    Write-Host "Module validation passed" -ForegroundColor Green
    Write-Host "  Name: $($manifest.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
    Write-Host "  Author: $($manifest.Author)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Error "Module validation failed: $_"
    exit 1
}

# Run tests
if ($Test) {
    Write-Host "Running tests..." -ForegroundColor Cyan

    # Check if Pester is installed
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Warning "Pester not installed. Installing..."
        Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
    }

    if (Test-Path $testsPath) {
        $testResults = Invoke-Pester -Path $testsPath -PassThru

        if ($testResults.FailedCount -gt 0) {
            Write-Error "Tests failed: $($testResults.FailedCount) test(s) failed"
            exit 1
        }

        Write-Host "All tests passed!`n" -ForegroundColor Green
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

    # Copy README
    Copy-Item -Path (Join-Path $projectRoot "README.md") -Destination $packagePath -Force

    # Create installation script
    $installScript = @"
# oof-foo Installation Script

Write-Host "Installing oof-foo..." -ForegroundColor Green

# Check PowerShell version
if (`$PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "PowerShell 5.1 or later is required"
    exit 1
}

# Get installation directory
`$installPath = Join-Path `$env:USERPROFILE "Documents\WindowsPowerShell\Modules\OofFoo"

# Create directory if it doesn't exist
if (-not (Test-Path `$installPath)) {
    New-Item -Path `$installPath -ItemType Directory -Force | Out-Null
}

# Copy module files
Write-Host "Copying module files to: `$installPath"
Copy-Item -Path ".\src\OofFoo\*" -Destination `$installPath -Recurse -Force

# Create desktop shortcut
`$desktopPath = [Environment]::GetFolderPath("Desktop")
`$shortcutPath = Join-Path `$desktopPath "oof-foo.lnk"

`$WScriptShell = New-Object -ComObject WScript.Shell
`$shortcut = `$WScriptShell.CreateShortcut(`$shortcutPath)
`$shortcut.TargetPath = "powershell.exe"
`$shortcut.Arguments = "-ExecutionPolicy Bypass -File `"`$(Join-Path `$PSScriptRoot 'oof-foo.ps1')`""
`$shortcut.WorkingDirectory = `$PSScriptRoot
`$shortcut.Description = "oof-foo - System Maintenance Tool"
`$shortcut.Save()

Write-Host "`nInstallation complete!" -ForegroundColor Green
Write-Host "You can now run: Import-Module OofFoo" -ForegroundColor Cyan
Write-Host "Or use the desktop shortcut to launch the GUI`n" -ForegroundColor Cyan
"@

    $installScript | Out-File -FilePath (Join-Path $packagePath "Install.ps1") -Encoding UTF8

    # Create ZIP archive
    $zipPath = Join-Path $buildOutputPath "$packageName.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Write-Host "Creating ZIP archive..." -ForegroundColor Gray
    Compress-Archive -Path "$packagePath\*" -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host "Package created: $zipPath" -ForegroundColor Green
    Write-Host "Package size: $([math]::Round((Get-Item $zipPath).Length / 1KB, 2)) KB`n" -ForegroundColor Cyan
}

Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Output directory: $buildOutputPath" -ForegroundColor Cyan
