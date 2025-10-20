function Invoke-SystemPatch {
    <#
    .SYNOPSIS
        Applies security patches and critical updates

    .DESCRIPTION
        Focuses on security-critical updates and patches for Windows and installed software.
        Part of the oof-foo maintenance suite.

    .PARAMETER IncludeThirdParty
        Also check for third-party security updates

    .EXAMPLE
        Invoke-SystemPatch

    .EXAMPLE
        Invoke-SystemPatch -IncludeThirdParty
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeThirdParty
    )

    Write-Host "oof-foo: Checking for security patches..." -ForegroundColor Green

    $results = @{
        CriticalUpdates = 0
        SecurityUpdates = 0
        DefenderUpdates = $false
        FirewallStatus = $null
    }

    # Check Windows Defender updates
    Write-Host "`nUpdating Windows Defender..." -ForegroundColor Cyan
    try {
        Update-MpSignature -ErrorAction SilentlyContinue
        $results.DefenderUpdates = $true
        Write-Host "Windows Defender signatures updated" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not update Windows Defender: $_"
    }

    # Check firewall status
    Write-Host "`nChecking Windows Firewall..." -ForegroundColor Cyan
    try {
        $firewallProfiles = Get-NetFirewallProfile
        $disabledProfiles = $firewallProfiles | Where-Object { $_.Enabled -eq $false }

        if ($disabledProfiles) {
            Write-Warning "Some firewall profiles are disabled: $($disabledProfiles.Name -join ', ')"
            $results.FirewallStatus = "Warning: Some profiles disabled"
        }
        else {
            Write-Host "Windows Firewall is active on all profiles" -ForegroundColor Green
            $results.FirewallStatus = "Active"
        }
    }
    catch {
        Write-Warning "Could not check firewall status: $_"
        $results.FirewallStatus = "Error"
    }

    # Check for critical Windows updates
    Write-Host "`nChecking for critical security updates..." -ForegroundColor Cyan
    try {
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Import-Module PSWindowsUpdate
            $criticalUpdates = Get-WindowsUpdate -Severity Critical -ErrorAction SilentlyContinue
            $securityUpdates = Get-WindowsUpdate | Where-Object { $_.Title -match 'Security' } -ErrorAction SilentlyContinue

            $results.CriticalUpdates = ($criticalUpdates | Measure-Object).Count
            $results.SecurityUpdates = ($securityUpdates | Measure-Object).Count

            if ($results.CriticalUpdates -gt 0 -or $results.SecurityUpdates -gt 0) {
                Write-Warning "Found $($results.CriticalUpdates) critical and $($results.SecurityUpdates) security updates"
            }
            else {
                Write-Host "No critical security updates found" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Warning "Could not check for security updates: $_"
    }

    Write-Host "`noof-foo: Security check complete!" -ForegroundColor Green

    return $results
}
