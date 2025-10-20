# oof-foo PowerShell Module
# All-in-one Windows system maintenance, updating, and patching tool

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\GUI\*.ps1 -ErrorAction SilentlyContinue)
$Public += @(Get-ChildItem -Path $PSScriptRoot\Modules\**\*.ps1 -Recurse -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in $Public) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Start-OofFooGUI',
    'Invoke-SystemUpdate',
    'Invoke-SystemMaintenance',
    'Invoke-SystemPatch',
    'Get-SystemHealth'
)
