#Requires -RunAsAdministrator
<#
.SYNOPSIS
    oof.foo Profile Cleanup — remove stale/unused user profiles with delprof2.

.DESCRIPTION
    Uses delprof2 (by Helge Klein) to clean up user profiles before handing off
    a machine to a new user or just cleaning up accumulated accounts.

    Two modes:
      - New user setup: delete ALL unused profiles (clean slate)
      - Existing user:  delete all profiles EXCEPT the specified user

    delprof2 is better than built-in profile management — it handles locked
    files, temp profiles, and ghost accounts reliably.

.PARAMETER ExcludeUser
    Username whose profile should be preserved. All other non-system profiles
    will be removed. If not specified, ALL unused profiles are removed.

.PARAMETER DelProf2Path
    Path to delprof2.exe. If not found, the script will attempt to download it.

.PARAMETER WhatIf
    Show what would be deleted without actually deleting.

.EXAMPLE
    .\cleanup-profiles.ps1
    Removes ALL unused/stale profiles. Clean slate for a new user.

.EXAMPLE
    .\cleanup-profiles.ps1 -ExcludeUser "jsmith"
    Removes all profiles except jsmith's. Good for reassigning a machine.

.EXAMPLE
    .\cleanup-profiles.ps1 -ExcludeUser "jsmith" -WhatIf
    Shows what would be removed without actually doing it.

.NOTES
    Part of oof.foo — https://oof.foo
    Origin: Dan Johnston's standard machine handoff procedure at KWES
    Requires: delprof2 by Helge Klein (free) — https://helgeklein.com/free-tools/delprof2/
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ExcludeUser,
    [string]$DelProf2Path
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Step, [string]$Description)
    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host " oof.foo cleanup-profiles | $Step" -ForegroundColor Cyan
    Write-Host " $Description" -ForegroundColor White
    Write-Host "────────────────────────────────────────" -ForegroundColor Cyan
}

# ─── Find or Download delprof2 ───────────────────────────────────────────────
Write-Step "Step 1/3" "Locating delprof2"

$searchPaths = @(
    $DelProf2Path,
    "$PSScriptRoot\delprof2.exe",
    "$env:TEMP\oof-foo\delprof2.exe",
    "C:\Tools\delprof2.exe",
    "C:\Scripts\delprof2.exe"
) | Where-Object { $_ }

$delprof2 = $null
foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $delprof2 = $path
        break
    }
}

if (-not $delprof2) {
    Write-Host "  delprof2 not found locally. Attempting download..." -ForegroundColor Yellow

    $downloadDir = "$env:TEMP\oof-foo"
    if (-not (Test-Path $downloadDir)) {
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    }

    $zipPath = "$downloadDir\delprof2.zip"
    $downloadUrl = "https://helgeklein.com/wp-content/uploads/2023/03/DelProf2-1.6.2.zip"

    try {
        Write-Host "  Downloading from helgeklein.com..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $downloadDir -Force

        # Find delprof2.exe in extracted files
        $delprof2 = Get-ChildItem -Path $downloadDir -Recurse -Filter "delprof2.exe" |
            Select-Object -First 1 -ExpandProperty FullName

        if ($delprof2) {
            Write-Host "  Downloaded and extracted: $delprof2" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Could not download delprof2. Please download manually from https://helgeklein.com/free-tools/delprof2/ and specify -DelProf2Path."
        exit 1
    }
}

if (-not $delprof2 -or -not (Test-Path $delprof2)) {
    Write-Error "delprof2.exe not found. Cannot continue."
    exit 1
}

Write-Host "  Using: $delprof2" -ForegroundColor Green

# ─── Show Current Profiles ───────────────────────────────────────────────────
Write-Step "Step 2/3" "Enumerating user profiles"

$profiles = Get-WmiObject Win32_UserProfile | Where-Object {
    -not $_.Special -and $_.LocalPath -notmatch '\\(systemprofile|LocalService|NetworkService)$'
}

Write-Host ""
Write-Host "  Current profiles on this machine:" -ForegroundColor White
foreach ($p in $profiles) {
    $username = Split-Path $p.LocalPath -Leaf
    $lastUse = if ($p.LastUseTime) {
        [System.Management.ManagementDateTimeConverter]::ToDateTime($p.LastUseTime).ToString("yyyy-MM-dd")
    } else { "unknown" }
    $sizeGB = try {
        $size = (Get-ChildItem -Path $p.LocalPath -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        "{0:N1} GB" -f ($size / 1GB)
    } catch { "? GB" }

    $marker = ""
    if ($ExcludeUser -and $username -eq $ExcludeUser) {
        $marker = " [KEEP]"
    }

    Write-Host "    $username — last used: $lastUse — $sizeGB$marker"
}

# ─── Run delprof2 ────────────────────────────────────────────────────────────
Write-Step "Step 3/3" "Running delprof2"

$args = @('/u', '/i')

if ($ExcludeUser) {
    $args += "/ed:$ExcludeUser"
    Write-Host "  Mode: Removing all profiles EXCEPT '$ExcludeUser'" -ForegroundColor Yellow
}
else {
    Write-Host "  Mode: Removing ALL unused profiles (clean slate)" -ForegroundColor Yellow
}

if ($WhatIfPreference) {
    $args += '/l'  # List only, don't delete
    Write-Host "  [WhatIf] Listing only — no profiles will be deleted" -ForegroundColor Cyan
}

Write-Host "  Command: $delprof2 $($args -join ' ')" -ForegroundColor Gray
Write-Host ""

& $delprof2 @args

# ─── Done ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "────────────────────────────────────────" -ForegroundColor Green
Write-Host " oof.foo cleanup-profiles complete" -ForegroundColor Green
if ($ExcludeUser) {
    Write-Host " Kept: $ExcludeUser" -ForegroundColor White
}
Write-Host "────────────────────────────────────────" -ForegroundColor Green
Write-Host ""
Write-Host "foo." -ForegroundColor Green
