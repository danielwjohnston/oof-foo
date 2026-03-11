#Requires -RunAsAdministrator
<#
.SYNOPSIS
    oof.foo Full PC Tune-Up — Dan's standard touch sequence.

.DESCRIPTION
    Runs the complete maintenance sequence for handing off or refreshing a Windows machine:
      1. SFC /scannow           — system file integrity check
      2. DISM RestoreHealth     — repairs the Windows image
      3. Disk Cleanup           — removes temp files, system cache, etc.
      4. Optimize drive         — trims SSD or defrags HDD
      5. Schedule chkdsk /r     — disk scan + bad sector recovery on next reboot
      6. Winget upgrade         — updates all installed apps
      7. Windows Update         — installs all available patches

    Designed to run unattended. The final reboot (from Windows Update or chkdsk)
    means the machine boots clean in the morning.

.PARAMETER SkipReboot
    If specified, skips the final forced reboot. chkdsk /r will still be
    scheduled and will run on the next manual reboot.

.PARAMETER SkipWinget
    If specified, skips the Winget upgrade step.

.PARAMETER SkipWindowsUpdate
    If specified, skips the Windows Update step.

.EXAMPLE
    .\full-tuneup.ps1
    Runs the full sequence and reboots at the end.

.EXAMPLE
    .\full-tuneup.ps1 -SkipReboot
    Runs everything but leaves the machine running for manual reboot.

.NOTES
    Part of oof.foo — https://oof.foo
    Origin: Dan Johnston's standard maintenance sequence at KWES (NewsWest 9)
    Order matters: SFC before DISM (DISM fixes what SFC draws from)
#>

[CmdletBinding()]
param(
    [switch]$SkipReboot,
    [switch]$SkipWinget,
    [switch]$SkipWindowsUpdate
)

$ErrorActionPreference = 'Continue'
$startTime = Get-Date

function Write-Step {
    param([string]$Step, [string]$Description)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " oof.foo tuneup | Step $Step" -ForegroundColor Cyan
    Write-Host " $Description" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# ─── Step 1: System File Checker ─────────────────────────────────────────────
Write-Step "1/7" "SFC /scannow — system file integrity check"
sfc /scannow

# ─── Step 2: DISM RestoreHealth ──────────────────────────────────────────────
Write-Step "2/7" "DISM /Online /Cleanup-Image /RestoreHealth"
DISM /Online /Cleanup-Image /RestoreHealth

# ─── Step 3: Disk Cleanup ────────────────────────────────────────────────────
Write-Step "3/7" "Disk Cleanup — removing temp files and system cache"

# Set registry keys to auto-select all cleanup categories
$volumeCache = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
Get-ChildItem $volumeCache | ForEach-Object {
    Set-ItemProperty -Path $_.PSPath -Name 'StateFlags0099' -Value 2 -Type DWord -ErrorAction SilentlyContinue
}
# Run cleanmgr with our custom state flags and wait for completion
Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:99' -Wait

# ─── Step 4: Optimize Drive ─────────────────────────────────────────────────
Write-Step "4/7" "Optimize-Volume C: — trim (SSD) or defrag (HDD)"
Optimize-Volume -DriveLetter C -Verbose

# ─── Step 5: Schedule chkdsk ────────────────────────────────────────────────
Write-Step "5/7" "chkdsk /r C: — scheduling disk scan for next reboot"

# Schedule chkdsk on next reboot (requires reboot to run)
Write-Host "Scheduling chkdsk /r on C: for next reboot..."
$result = echo Y | chkdsk C: /r
Write-Host $result

# ─── Step 6: Winget Upgrade ─────────────────────────────────────────────────
if (-not $SkipWinget) {
    Write-Step "6/7" "Winget upgrade — updating all installed applications"
    try {
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --include-unknown
    }
    catch {
        Write-Warning "Winget upgrade encountered an error: $_"
    }
}
else {
    Write-Step "6/7" "Winget upgrade — SKIPPED (user requested)"
}

# ─── Step 7: Windows Update ─────────────────────────────────────────────────
if (-not $SkipWindowsUpdate) {
    Write-Step "7/7" "Windows Update — installing all available patches"

    # Install PSWindowsUpdate module if not present
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "Installing PSWindowsUpdate module..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction Stop
    }

    Import-Module PSWindowsUpdate -Force
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose
}
else {
    Write-Step "7/7" "Windows Update — SKIPPED (user requested)"
}

# ─── Summary ─────────────────────────────────────────────────────────────────
$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " oof.foo tuneup complete" -ForegroundColor Green
Write-Host " Elapsed: $([math]::Round($elapsed.TotalMinutes, 1)) minutes" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "What was done:" -ForegroundColor White
Write-Host "  [x] System files checked (SFC)" -ForegroundColor Gray
Write-Host "  [x] Windows image repaired (DISM)" -ForegroundColor Gray
Write-Host "  [x] Disk cleaned (cleanmgr)" -ForegroundColor Gray
Write-Host "  [x] Drive optimized (trim/defrag)" -ForegroundColor Gray
Write-Host "  [x] Disk check scheduled for reboot (chkdsk /r)" -ForegroundColor Gray
if (-not $SkipWinget)        { Write-Host "  [x] Apps updated (Winget)" -ForegroundColor Gray }
if (-not $SkipWindowsUpdate) { Write-Host "  [x] Windows patches installed" -ForegroundColor Gray }
Write-Host ""

if (-not $SkipReboot) {
    Write-Host "Rebooting in 30 seconds... (Ctrl+C to cancel)" -ForegroundColor Yellow
    Write-Host "chkdsk will run during boot. Machine will be clean when it comes back up." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Restart-Computer -Force
}
else {
    Write-Host "Reboot skipped. Remember to reboot so chkdsk /r can run." -ForegroundColor Yellow
    Write-Host "foo." -ForegroundColor Green
}
