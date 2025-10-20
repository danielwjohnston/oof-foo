function Test-OofFooAdministrator {
    <#
    .SYNOPSIS
        Tests if running with administrator privileges

    .DESCRIPTION
        Returns true if the current PowerShell session has administrator privileges.

    .EXAMPLE
        if (Test-OofFooAdministrator) { ... }
    #>

    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-OofFooElevated {
    <#
    .SYNOPSIS
        Restarts the script with administrator privileges

    .DESCRIPTION
        Relaunches the current script or command with elevated privileges.

    .PARAMETER ScriptPath
        Path to the script to run elevated

    .PARAMETER ArgumentList
        Arguments to pass to the elevated script

    .EXAMPLE
        Start-OofFooElevated -ScriptPath ".\oof-foo.ps1" -ArgumentList "-GUI"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter()]
        [string[]]$ArgumentList
    )

    if (Test-OofFooAdministrator) {
        Write-Warning "Already running as administrator"
        return
    }

    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
        if ($ArgumentList) {
            $arguments += " " + ($ArgumentList -join " ")
        }

        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
        exit
    }
    catch {
        Write-Error "Failed to elevate: $_"
    }
}

function New-OofFooRestorePoint {
    <#
    .SYNOPSIS
        Creates a system restore point before maintenance

    .DESCRIPTION
        Creates a Windows System Restore point to allow rollback if needed.
        Requires administrator privileges.

    .PARAMETER Description
        Description for the restore point

    .EXAMPLE
        New-OofFooRestorePoint -Description "Before oof-foo maintenance"
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Description = "oof-foo maintenance - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    )

    if (-not (Test-OofFooAdministrator)) {
        Write-Warning "Creating restore point requires administrator privileges"
        return $false
    }

    try {
        Write-OofFooLog "Creating system restore point: $Description" -Level Information

        # Enable System Restore if not enabled
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

        # Create restore point (limit to once per day)
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop

        Write-OofFooLog "System restore point created successfully" -Level Information
        return $true
    }
    catch {
        if ($_.Exception.Message -match "restore point.*24 hours") {
            Write-OofFooLog "Restore point already created today" -Level Warning
            return $true
        }

        Write-OofFooLog "Failed to create restore point: $_" -Level Warning
        return $false
    }
}

function Get-OofFooFreeSpace {
    <#
    .SYNOPSIS
        Gets free disk space for a drive

    .PARAMETER DriveLetter
        Drive letter to check (default: C)

    .EXAMPLE
        Get-OofFooFreeSpace -DriveLetter C
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DriveLetter = "C"
    )

    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${DriveLetter}:'"

    return [PSCustomObject]@{
        Drive = $drive.DeviceID
        FreeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        TotalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
        UsedPercent = [math]::Round((($drive.Size - $drive.FreeSpace) / $drive.Size) * 100, 1)
        FreeSpaceBytes = $drive.FreeSpace
    }
}

function Invoke-OofFooWithProgress {
    <#
    .SYNOPSIS
        Executes a script block with progress reporting

    .PARAMETER ScriptBlock
        Script block to execute

    .PARAMETER Activity
        Activity description for progress bar

    .PARAMETER Status
        Status message for progress bar

    .EXAMPLE
        Invoke-OofFooWithProgress -ScriptBlock { Do-Something } -Activity "Processing" -Status "Working..."
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter()]
        [string]$Status = "Please wait..."
    )

    try {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete 0

        $result = & $ScriptBlock

        Write-Progress -Activity $Activity -Completed

        return $result
    }
    catch {
        Write-Progress -Activity $Activity -Completed
        throw
    }
}

function Test-OofFooOnline {
    <#
    .SYNOPSIS
        Tests if system has internet connectivity

    .DESCRIPTION
        Checks connectivity to Microsoft servers and returns true if online.

    .EXAMPLE
        if (Test-OofFooOnline) { ... }
    #>

    [CmdletBinding()]
    param()

    try {
        $result = Test-Connection -ComputerName "www.microsoft.com" -Count 1 -Quiet -ErrorAction Stop
        return $result
    }
    catch {
        return $false
    }
}

function ConvertTo-OofFooReadableSize {
    <#
    .SYNOPSIS
        Converts bytes to human-readable size

    .PARAMETER Bytes
        Number of bytes

    .EXAMPLE
        ConvertTo-OofFooReadableSize -Bytes 1234567890
        Returns: "1.15 GB"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )

    if ($Bytes -ge 1TB) {
        return "{0:N2} TB" -f ($Bytes / 1TB)
    }
    elseif ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes bytes"
    }
}
