function Get-SystemHealth {
    <#
    .SYNOPSIS
        Generates a comprehensive system health report

    .DESCRIPTION
        Analyzes system health including disk space, memory, updates, security status,
        and other key metrics. Part of the oof-foo maintenance suite.

    .PARAMETER Detailed
        Include detailed information in the report

    .EXAMPLE
        Get-SystemHealth

    .EXAMPLE
        Get-SystemHealth -Detailed | Out-File health-report.txt
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Detailed
    )

    Write-Host "oof-foo: Generating system health report..." -ForegroundColor Green

    $report = @{
        Timestamp = Get-Date
        OverallHealth = "Unknown"
        System = @{}
        Disk = @{}
        Memory = @{}
        Security = @{}
        Updates = @{}
        Warnings = @()
    }

    # System Information
    Write-Host "`nGathering system information..." -ForegroundColor Cyan
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem

    $report.System = @{
        OS = $os.Caption
        Version = $os.Version
        Architecture = $os.OSArchitecture
        ComputerName = $computer.Name
        LastBoot = $os.LastBootUpTime
        Uptime = (Get-Date) - $os.LastBootUpTime
    }

    # Disk Information
    Write-Host "Checking disk space..." -ForegroundColor Cyan
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $report.Disk.Drives = @()

    foreach ($disk in $disks) {
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($disk.Size / 1GB, 2)
        $usedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)

        $diskInfo = @{
            Drive = $disk.DeviceID
            FreeGB = $freeGB
            TotalGB = $totalGB
            UsedPercent = $usedPercent
            Status = if ($usedPercent -gt 90) { "Critical" } elseif ($usedPercent -gt 85) { "Warning" } else { "OK" }
        }

        $report.Disk.Drives += $diskInfo

        if ($usedPercent -gt 85) {
            $report.Warnings += "Disk $($disk.DeviceID) is $usedPercent% full"
        }
    }

    # Memory Information
    Write-Host "Checking memory..." -ForegroundColor Cyan
    $totalMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMemPercent = [math]::Round((($totalMemGB - $freeMemGB) / $totalMemGB) * 100, 1)

    $report.Memory = @{
        TotalGB = $totalMemGB
        FreeGB = $freeMemGB
        UsedPercent = $usedMemPercent
        Status = if ($usedMemPercent -gt 95) { "Critical" } elseif ($usedMemPercent -gt 90) { "Warning" } else { "OK" }
    }

    # Security Status
    Write-Host "Checking security status..." -ForegroundColor Cyan
    try {
        $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
        $report.Security.Defender = @{
            Enabled = $defender.AntivirusEnabled
            Updated = $defender.AntivirusSignatureLastUpdated
            RealTimeProtection = $defender.RealTimeProtectionEnabled
            Status = if ($defender.AntivirusEnabled -and $defender.RealTimeProtectionEnabled) { "Protected" } else { "At Risk" }
        }

        if (-not $defender.AntivirusEnabled) {
            $report.Warnings += "Windows Defender is disabled"
        }
    }
    catch {
        $report.Security.Defender = @{ Status = "Unknown" }
    }

    # Firewall Status
    try {
        $firewallProfiles = Get-NetFirewallProfile
        $enabledProfiles = ($firewallProfiles | Where-Object { $_.Enabled }).Count
        $totalProfiles = $firewallProfiles.Count

        $report.Security.Firewall = @{
            EnabledProfiles = $enabledProfiles
            TotalProfiles = $totalProfiles
            Status = if ($enabledProfiles -eq $totalProfiles) { "Active" } else { "Partial" }
        }

        if ($enabledProfiles -lt $totalProfiles) {
            $report.Warnings += "Some firewall profiles are disabled"
        }
    }
    catch {
        $report.Security.Firewall = @{ Status = "Unknown" }
    }

    # Windows Update Status
    Write-Host "Checking update status..." -ForegroundColor Cyan
    try {
        $lastUpdate = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
        $report.Updates.LastInstalled = $lastUpdate

        if ($lastUpdate -lt (Get-Date).AddDays(-30)) {
            $report.Warnings += "No updates installed in the last 30 days"
        }
    }
    catch {
        $report.Updates.LastInstalled = "Unknown"
    }

    # Calculate overall health
    $criticalIssues = ($report.Warnings | Where-Object { $_ -match "Critical|disabled" }).Count
    $report.OverallHealth = if ($criticalIssues -gt 0) {
        "Needs Attention"
    } elseif ($report.Warnings.Count -gt 0) {
        "Fair"
    } else {
        "Good"
    }

    Write-Host "`noof-foo: Health check complete!" -ForegroundColor Green
    Write-Host "Overall Health: $($report.OverallHealth)" -ForegroundColor $(
        if ($report.OverallHealth -eq "Good") { "Green" }
        elseif ($report.OverallHealth -eq "Fair") { "Yellow" }
        else { "Red" }
    )

    if ($report.Warnings.Count -gt 0) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        $report.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }

    return $report
}
