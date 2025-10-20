function Write-OofFooLog {
    <#
    .SYNOPSIS
        Writes a log entry to the oof-foo log file

    .DESCRIPTION
        Writes timestamped log entries to a log file with severity levels.
        Automatically rotates logs based on configuration.

    .PARAMETER Message
        The message to log

    .PARAMETER Level
        Log level: Verbose, Information, Warning, Error

    .PARAMETER NoConsole
        Don't also write to console

    .EXAMPLE
        Write-OofFooLog "Starting maintenance" -Level Information

    .EXAMPLE
        Write-OofFooLog "Failed to clean temp files" -Level Error
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Verbose', 'Information', 'Warning', 'Error')]
        [string]$Level = 'Information',

        [Parameter()]
        [switch]$NoConsole
    )

    $config = Get-OofFooConfig

    if (-not $config.Logging.Enabled) {
        return
    }

    $logPath = Get-OofFooLogPath
    $logDir = Split-Path $logPath -Parent

    # Create log directory if needed
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Rotate log if needed
    if (Test-Path $logPath) {
        $logSize = (Get-Item $logPath).Length / 1KB
        if ($logSize -gt $config.Logging.MaxLogSizeKB) {
            $archivePath = $logPath -replace '\.log$', "-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            Move-Item $logPath $archivePath -Force
        }
    }

    # Format log entry
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to log file
    try {
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }

    # Write to console unless suppressed
    if (-not $NoConsole) {
        switch ($Level) {
            'Verbose'     { Write-Verbose $Message }
            'Information' { Write-Host $Message -ForegroundColor Cyan }
            'Warning'     { Write-Warning $Message }
            'Error'       { Write-Host $Message -ForegroundColor Red }
        }
    }

    # Clean old logs
    Remove-OofFooOldLogs
}

function Get-OofFooLogPath {
    <#
    .SYNOPSIS
        Gets the path to the current log file
    #>

    $appDataPath = [Environment]::GetFolderPath('ApplicationData')
    return Join-Path $appDataPath "OofFoo\Logs\oof-foo.log"
}

function Remove-OofFooOldLogs {
    <#
    .SYNOPSIS
        Removes old log files based on retention policy
    #>

    [CmdletBinding()]
    param()

    $config = Get-OofFooConfig
    $logDir = Split-Path (Get-OofFooLogPath) -Parent

    if (-not (Test-Path $logDir)) {
        return
    }

    $cutoffDate = (Get-Date).AddDays(-$config.Logging.RetainDays)

    Get-ChildItem $logDir -Filter "*.log" |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Get-OofFooLogs {
    <#
    .SYNOPSIS
        Retrieves log entries from the log file

    .PARAMETER Last
        Number of last entries to retrieve

    .PARAMETER Level
        Filter by log level

    .EXAMPLE
        Get-OofFooLogs -Last 100

    .EXAMPLE
        Get-OofFooLogs -Level Error
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Last = 50,

        [Parameter()]
        [ValidateSet('Verbose', 'Information', 'Warning', 'Error')]
        [string]$Level
    )

    $logPath = Get-OofFooLogPath

    if (-not (Test-Path $logPath)) {
        Write-Warning "No log file found at $logPath"
        return
    }

    $logs = Get-Content $logPath -Tail $Last

    if ($Level) {
        $logs = $logs | Where-Object { $_ -match "\[$Level\]" }
    }

    return $logs
}
