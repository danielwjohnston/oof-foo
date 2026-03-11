#Requires -RunAsAdministrator
<#
.SYNOPSIS
    oof.foo NIC Reinstall — the fastest way to fix DHCP/connectivity issues.

.DESCRIPTION
    IT tribal knowledge, codified. When a network adapter is misbehaving
    (DHCP won't renew, adapter stuck, intermittent drops), the fastest fix
    is often a clean reinstall of the driver:

      1. Document current IP config (in case it's static)
      2. Back up the NIC driver via pnputil
      3. Uninstall the NIC completely via Device Manager
      4. Rescan for hardware changes (Windows reinstalls the NIC)
      5. Restore the backed-up driver if needed
      6. Reconfigure static IP if the adapter had one
      7. Check hosts file for weird routing entries while we're in there

    Bob's your uncle.

.PARAMETER AdapterName
    Name of the network adapter to reinstall. If not specified, shows a menu
    of available adapters.

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\nic-reinstall.ps1
    Shows adapter menu, backs up driver, reinstalls, reconfigures.

.EXAMPLE
    .\nic-reinstall.ps1 -AdapterName "Ethernet" -Force
    Reinstalls the adapter named "Ethernet" without prompts.

.NOTES
    Part of oof.foo — https://oof.foo
    Origin: Dan Johnston's go-to fix for stubborn network issues at KWES
#>

[CmdletBinding()]
param(
    [string]$AdapterName,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$backupPath = "$env:TEMP\oof-foo-nic-backup"

function Write-Step {
    param([string]$Step, [string]$Description)
    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host " oof.foo nic-reinstall | $Step" -ForegroundColor Cyan
    Write-Host " $Description" -ForegroundColor White
    Write-Host "────────────────────────────────────────" -ForegroundColor Cyan
}

# ─── Select Adapter ──────────────────────────────────────────────────────────
$adapters = Get-NetAdapter | Where-Object { $_.Status -ne 'Not Present' }

if (-not $AdapterName) {
    Write-Host ""
    Write-Host "Available network adapters:" -ForegroundColor White
    Write-Host ""
    $i = 1
    foreach ($a in $adapters) {
        $status = if ($a.Status -eq 'Up') { '[UP]' } else { '[DOWN]' }
        $statusColor = if ($a.Status -eq 'Up') { 'Green' } else { 'Yellow' }
        Write-Host "  $i. $($a.Name) — $($a.InterfaceDescription) " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
        $i++
    }
    Write-Host ""
    $selection = Read-Host "Select adapter number"
    $selectedAdapter = $adapters[$selection - 1]
    if (-not $selectedAdapter) {
        Write-Error "Invalid selection."
        exit 1
    }
}
else {
    $selectedAdapter = $adapters | Where-Object { $_.Name -eq $AdapterName }
    if (-not $selectedAdapter) {
        Write-Error "Adapter '$AdapterName' not found."
        exit 1
    }
}

$adapterDisplayName = $selectedAdapter.Name
$adapterDescription = $selectedAdapter.InterfaceDescription
Write-Host ""
Write-Host "Selected: $adapterDisplayName ($adapterDescription)" -ForegroundColor Green

# ─── Step 1: Document Current IP Configuration ──────────────────────────────
Write-Step "Step 1/6" "Documenting current IP configuration"

$ipConfig = Get-NetIPConfiguration -InterfaceIndex $selectedAdapter.ifIndex
$currentIP = Get-NetIPAddress -InterfaceIndex $selectedAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
$dhcpEnabled = (Get-NetIPInterface -InterfaceIndex $selectedAdapter.ifIndex -AddressFamily IPv4).Dhcp

Write-Host "  Interface:   $adapterDisplayName"
Write-Host "  DHCP:        $dhcpEnabled"
if ($currentIP) {
    Write-Host "  IP Address:  $($currentIP.IPAddress)"
    Write-Host "  Prefix:      /$($currentIP.PrefixLength)"
}
if ($ipConfig.IPv4DefaultGateway) {
    Write-Host "  Gateway:     $($ipConfig.IPv4DefaultGateway.NextHop)"
}
$dnsServers = Get-DnsClientServerAddress -InterfaceIndex $selectedAdapter.ifIndex -AddressFamily IPv4
if ($dnsServers.ServerAddresses) {
    Write-Host "  DNS:         $($dnsServers.ServerAddresses -join ', ')"
}

# Save config for potential restore
$savedConfig = @{
    DHCP       = $dhcpEnabled
    IP         = if ($currentIP) { $currentIP.IPAddress } else { $null }
    Prefix     = if ($currentIP) { $currentIP.PrefixLength } else { $null }
    Gateway    = if ($ipConfig.IPv4DefaultGateway) { $ipConfig.IPv4DefaultGateway.NextHop } else { $null }
    DNS        = $dnsServers.ServerAddresses
}

$isStatic = ($dhcpEnabled -eq 'Disabled')
if ($isStatic) {
    Write-Host ""
    Write-Host "  ** Static IP detected — will reconfigure after reinstall **" -ForegroundColor Yellow
}

# ─── Step 2: Back Up NIC Driver ──────────────────────────────────────────────
Write-Step "Step 2/6" "Backing up NIC driver"

if (-not (Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
}

# Get the driver for this adapter
$driver = Get-WmiObject Win32_PnPSignedDriver | Where-Object {
    $_.Description -eq $adapterDescription
}

if ($driver -and $driver.InfName) {
    Write-Host "  Driver: $($driver.InfName) ($($driver.DriverVersion))"
    pnputil /export-driver $driver.InfName $backupPath
    Write-Host "  Backed up to: $backupPath" -ForegroundColor Green
}
else {
    Write-Warning "Could not identify driver INF for backup. Proceeding anyway — Windows should auto-detect on rescan."
}

# ─── Confirmation ────────────────────────────────────────────────────────────
if (-not $Force) {
    Write-Host ""
    Write-Host "About to uninstall $adapterDisplayName ($adapterDescription)." -ForegroundColor Yellow
    Write-Host "Network connectivity on this adapter will be lost temporarily." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Red
        exit 0
    }
}

# ─── Step 3: Uninstall NIC ───────────────────────────────────────────────────
Write-Step "Step 3/6" "Uninstalling network adapter"

$pnpDevice = Get-PnpDevice | Where-Object {
    $_.FriendlyName -eq $adapterDescription -and $_.Class -eq 'Net'
}

if ($pnpDevice) {
    Write-Host "  Removing device: $($pnpDevice.InstanceId)"
    pnputil /remove-device $pnpDevice.InstanceId
    Start-Sleep -Seconds 3
    Write-Host "  Removed." -ForegroundColor Green
}
else {
    Write-Warning "Could not find PnP device entry. Trying Disable/Enable instead."
    Disable-NetAdapter -Name $adapterDisplayName -Confirm:$false
    Start-Sleep -Seconds 2
}

# ─── Step 4: Rescan for Hardware ─────────────────────────────────────────────
Write-Step "Step 4/6" "Scanning for hardware changes"

pnputil /scan-devices
Write-Host "  Waiting for Windows to reinstall the adapter..."
Start-Sleep -Seconds 10

# Wait for the adapter to come back
$attempts = 0
$maxAttempts = 12
while ($attempts -lt $maxAttempts) {
    $restoredAdapter = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -eq $adapterDescription
    }
    if ($restoredAdapter) {
        Write-Host "  Adapter reinstalled: $($restoredAdapter.Name)" -ForegroundColor Green
        break
    }
    $attempts++
    Write-Host "  Waiting... ($attempts/$maxAttempts)"
    Start-Sleep -Seconds 5
}

if (-not $restoredAdapter) {
    Write-Warning "Adapter did not reappear automatically."
    Write-Host "  Attempting to install backed-up driver..."
    if (Test-Path $backupPath) {
        pnputil /add-driver "$backupPath\*.inf" /install
        Start-Sleep -Seconds 5
        $restoredAdapter = Get-NetAdapter | Where-Object {
            $_.InterfaceDescription -eq $adapterDescription
        }
    }
    if (-not $restoredAdapter) {
        Write-Error "Adapter could not be restored. Check Device Manager manually."
        exit 1
    }
}

# ─── Step 5: Reconfigure Static IP (if needed) ──────────────────────────────
if ($isStatic -and $savedConfig.IP) {
    Write-Step "Step 5/6" "Reconfiguring static IP ($($savedConfig.IP))"

    $newAdapter = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -eq $adapterDescription
    }
    $ifIndex = $newAdapter.ifIndex

    # Remove any auto-configured addresses
    Remove-NetIPAddress -InterfaceIndex $ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $ifIndex -Confirm:$false -ErrorAction SilentlyContinue

    # Set static IP
    New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $savedConfig.IP -PrefixLength $savedConfig.Prefix -DefaultGateway $savedConfig.Gateway -ErrorAction Stop
    Write-Host "  IP: $($savedConfig.IP)/$($savedConfig.Prefix)" -ForegroundColor Green
    Write-Host "  Gateway: $($savedConfig.Gateway)" -ForegroundColor Green

    # Set DNS
    if ($savedConfig.DNS) {
        Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $savedConfig.DNS
        Write-Host "  DNS: $($savedConfig.DNS -join ', ')" -ForegroundColor Green
    }
}
else {
    Write-Step "Step 5/6" "DHCP adapter — waiting for address"
    Start-Sleep -Seconds 5
    $newIP = Get-NetIPAddress -InterfaceIndex $restoredAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($newIP) {
        Write-Host "  DHCP assigned: $($newIP.IPAddress)" -ForegroundColor Green
    }
    else {
        Write-Host "  Waiting for DHCP..." -ForegroundColor Yellow
        ipconfig /renew $restoredAdapter.Name
    }
}

# ─── Step 6: Check Hosts File ───────────────────────────────────────────────
Write-Step "Step 6/6" "Checking hosts file for unusual entries"

$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsFile -ErrorAction SilentlyContinue
$suspiciousEntries = $hostsContent | Where-Object {
    $_ -match '^\s*\d' -and $_ -notmatch '^\s*127\.0\.0\.1\s+localhost' -and $_ -notmatch '^\s*::1\s+localhost'
}

if ($suspiciousEntries) {
    Write-Host "  Found non-standard entries in hosts file:" -ForegroundColor Yellow
    foreach ($entry in $suspiciousEntries) {
        Write-Host "    $entry" -ForegroundColor Yellow
    }
    Write-Host "  Review these manually: $hostsFile" -ForegroundColor Yellow
}
else {
    Write-Host "  Hosts file looks clean." -ForegroundColor Green
}

# ─── Done ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "────────────────────────────────────────" -ForegroundColor Green
Write-Host " oof.foo nic-reinstall complete" -ForegroundColor Green
Write-Host " $adapterDisplayName is back online." -ForegroundColor White
Write-Host "────────────────────────────────────────" -ForegroundColor Green
Write-Host ""
Write-Host "Driver backup saved at: $backupPath" -ForegroundColor Gray
Write-Host "foo." -ForegroundColor Green
