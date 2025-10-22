@{
    # Script module or binary module file associated with this manifest
    RootModule = 'OofFoo.psm1'

    # Version number of this module
    ModuleVersion = '0.3.0'

    # ID used to uniquely identify this module
    GUID = '00ff0000-00ff-00ff-00ff-000000000000'

    # Author of this module
    Author = 'danielwjohnston'

    # Company or vendor of this module
    CompanyName = 'oof.foo'

    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'oof-foo: All-in-one Windows system maintenance, updating, and patching tool. From "oof" to "phew" in one click!'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        # GUI and Main Functions
        'Start-OofFooGUI',
        # Core Operations
        'Invoke-SystemUpdate',
        'Invoke-SystemMaintenance',
        'Invoke-AdvancedSystemMaintenance',
        'Invoke-SystemPatch',
        'Get-SystemHealth',
        # Configuration
        'Get-OofFooConfig',
        'Set-OofFooConfig',
        'Get-OofFooConfigPath',
        'Get-OofFooDefaultConfig',
        # Logging
        'Write-OofFooLog',
        'Get-OofFooLogs',
        'Get-OofFooLogPath',
        'Remove-OofFooOldLogs',
        # System Helpers
        'Test-OofFooAdministrator',
        'Start-OofFooElevated',
        'New-OofFooRestorePoint',
        'Get-OofFooFreeSpace',
        'Test-OofFooOnline',
        'ConvertTo-OofFooReadableSize',
        'Invoke-OofFooWithProgress',
        # Scheduled Tasks
        'New-OofFooScheduledTask',
        'Remove-OofFooScheduledTask',
        'Get-OofFooScheduledTask',
        'Test-OofFooScheduledTask'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Windows', 'Maintenance', 'Updates', 'System', 'Automation', 'GUI')

            # A URL to the license for this module
            LicenseUri = ''

            # A URL to the main website for this project
            ProjectUri = 'https://oof.foo'

            # ReleaseNotes of this module
            ReleaseNotes = @'
v0.3.0 - GUI Async + Advanced Features:
- ✨ ASYNC GUI - No more freezing! Uses PowerShell runspaces
- 🗓️ Scheduled task automation (New-OofFooScheduledTask)
- 🧹 Advanced cleanup (Windows.old, driver store, thumbnails)
- 📊 Better progress reporting in GUI
- 🔧 Improved test coverage (integration tests)
- 📝 Enhanced documentation
- 🎨 Better GUI layout and UX

v0.2.0 - Major improvements:
- Added comprehensive logging system
- Added configuration file support
- Implemented actual Windows Update installation
- Implemented actual winget/Chocolatey upgrades
- Added system restore point creation
- Added confirmation dialogs for destructive operations
- Improved error handling throughout
- Added PSScriptAnalyzer to build process
- Added GitHub Actions CI/CD pipeline
'@
        }
    }
}
