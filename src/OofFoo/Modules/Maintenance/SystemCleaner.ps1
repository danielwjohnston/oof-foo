function Invoke-SystemMaintenance {
    <#
    .SYNOPSIS
        Performs system cleanup and maintenance tasks

    .DESCRIPTION
        Cleans temporary files, clears caches, runs disk cleanup, and performs
        other routine maintenance tasks. Part of the oof-foo maintenance suite.

    .PARAMETER DeepClean
        Perform more aggressive cleanup (may take longer)

    .PARAMETER IncludeLogs
        Also clean old log files

    .EXAMPLE
        Invoke-SystemMaintenance

    .EXAMPLE
        Invoke-SystemMaintenance -DeepClean -IncludeLogs
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$DeepClean,

        [Parameter()]
        [switch]$IncludeLogs
    )

    Write-Host "oof-foo: Starting system maintenance..." -ForegroundColor Green

    $results = @{
        TempFilesRemoved = 0
        SpaceFreed = 0
        CachesCleared = @()
        Errors = @()
    }

    # Clean Windows Temp folder
    Write-Host "`nCleaning Windows temp files..." -ForegroundColor Cyan
    try {
        $tempPath = [System.IO.Path]::GetTempPath()
        $before = (Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

        Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        $after = (Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $freed = [math]::Round(($before - $after) / 1MB, 2)

        Write-Host "Cleaned Windows temp folder: $freed MB freed" -ForegroundColor Green
        $results.SpaceFreed += $freed
        $results.CachesCleared += "Windows Temp"
    }
    catch {
        Write-Warning "Error cleaning Windows temp: $_"
        $results.Errors += "Windows Temp: $_"
    }

    # Clean user temp folder
    Write-Host "`nCleaning user temp files..." -ForegroundColor Cyan
    try {
        $userTemp = $env:TEMP
        Get-ChildItem $userTemp -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Write-Host "Cleaned user temp folder" -ForegroundColor Green
        $results.CachesCleared += "User Temp"
    }
    catch {
        Write-Warning "Error cleaning user temp: $_"
        $results.Errors += "User Temp: $_"
    }

    # Clean Windows Update cache
    if ($DeepClean) {
        Write-Host "`nCleaning Windows Update cache..." -ForegroundColor Cyan
        try {
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            $updateCache = "$env:SystemRoot\SoftwareDistribution\Download"

            if (Test-Path $updateCache) {
                $cacheBefore = (Get-ChildItem $updateCache -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                Get-ChildItem $updateCache -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                $cacheFreed = [math]::Round($cacheBefore / 1MB, 2)

                Write-Host "Cleaned Windows Update cache: $cacheFreed MB freed" -ForegroundColor Green
                $results.SpaceFreed += $cacheFreed
                $results.CachesCleared += "Windows Update Cache"
            }

            Start-Service wuauserv -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Error cleaning Windows Update cache: $_"
            $results.Errors += "Windows Update Cache: $_"
        }
    }

    # Clean Recycle Bin
    Write-Host "`nEmptying Recycle Bin..." -ForegroundColor Cyan
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue -Confirm:$false
        Write-Host "Recycle Bin emptied" -ForegroundColor Green
        $results.CachesCleared += "Recycle Bin"
    }
    catch {
        Write-Warning "Error emptying Recycle Bin: $_"
        $results.Errors += "Recycle Bin: $_"
    }

    # Clean browser caches (if deep clean)
    if ($DeepClean) {
        Write-Host "`nCleaning browser caches..." -ForegroundColor Cyan

        # Chrome cache
        $chromeCaches = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        )

        foreach ($cache in $chromeCaches) {
            if (Test-Path $cache) {
                try {
                    Get-ChildItem $cache -Recurse -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    $results.CachesCleared += "Chrome Cache"
                }
                catch {
                    # Silently continue - browser might be running
                }
            }
        }

        # Edge cache
        $edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        if (Test-Path $edgeCache) {
            try {
                Get-ChildItem $edgeCache -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                $results.CachesCleared += "Edge Cache"
            }
            catch {
                # Silently continue
            }
        }

        Write-Host "Browser caches cleaned" -ForegroundColor Green
    }

    # Run Disk Cleanup (cleanmgr)
    Write-Host "`nPreparing disk cleanup..." -ForegroundColor Cyan
    try {
        # Set StateFlags for cleanup
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $caches = Get-ChildItem $regPath -ErrorAction SilentlyContinue

        foreach ($cache in $caches) {
            Set-ItemProperty -Path $cache.PSPath -Name "StateFlags0001" -Value 2 -ErrorAction SilentlyContinue
        }

        Write-Host "Disk cleanup configured (run cleanmgr /sagerun:1 to execute)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error configuring disk cleanup: $_"
    }

    Write-Host "`noof-foo: Maintenance complete!" -ForegroundColor Green
    Write-Host "Total space freed: $([math]::Round($results.SpaceFreed, 2)) MB" -ForegroundColor Cyan

    return $results
}
