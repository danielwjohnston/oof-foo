function Get-OofFooConfig {
    <#
    .SYNOPSIS
        Gets the oof-foo configuration

    .DESCRIPTION
        Loads configuration from JSON file or creates default configuration.
        Configuration is stored in user's AppData folder.

    .EXAMPLE
        $config = Get-OofFooConfig
    #>

    [CmdletBinding()]
    param()

    $configPath = Get-OofFooConfigPath

    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            return $config
        }
        catch {
            Write-Warning "Failed to load config from $configPath : $_"
            Write-Warning "Using default configuration"
        }
    }

    # Return default configuration
    return Get-OofFooDefaultConfig
}

function Set-OofFooConfig {
    <#
    .SYNOPSIS
        Saves the oof-foo configuration

    .DESCRIPTION
        Saves configuration to JSON file in user's AppData folder.

    .PARAMETER Config
        Configuration object to save

    .EXAMPLE
        Set-OofFooConfig -Config $config
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $configPath = Get-OofFooConfigPath
    $configDir = Split-Path $configPath -Parent

    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    try {
        $Config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        Write-Verbose "Configuration saved to $configPath"
    }
    catch {
        Write-Error "Failed to save configuration: $_"
    }
}

function Get-OofFooConfigPath {
    <#
    .SYNOPSIS
        Gets the path to the configuration file
    #>

    $appDataPath = [Environment]::GetFolderPath('ApplicationData')
    return Join-Path $appDataPath "OofFoo\config.json"
}

function Get-OofFooDefaultConfig {
    <#
    .SYNOPSIS
        Returns default configuration
    #>

    return [PSCustomObject]@{
        Version = "0.1.0"
        Logging = @{
            Enabled = $true
            Level = "Information"  # Verbose, Information, Warning, Error
            MaxLogSizeKB = 10240  # 10 MB
            RetainDays = 30
        }
        Maintenance = @{
            TempFileAgeDays = 7
            ConfirmDestructiveActions = $true
            CreateRestorePointBeforeMaintenance = $true
            AutoCleanRecycleBin = $false
        }
        Updates = @{
            CheckWindowsUpdate = $true
            CheckWinGet = $true
            CheckChocolatey = $false
            AutoInstallUpdates = $false
            AutoRestart = $false
        }
        GUI = @{
            WindowWidth = 800
            WindowHeight = 600
            Theme = "Green"  # Green, Blue, Dark
            ShowConfirmations = $true
        }
        Performance = @{
            MaxParallelOperations = 4
            TimeoutSeconds = 3600
        }
    }
}
