@{
    # Script module or binary module file associated with this manifest
    RootModule = 'OofFoo.psm1'

    # Version number of this module
    ModuleVersion = '0.1.0'

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
        'Start-OofFooGUI',
        'Invoke-SystemUpdate',
        'Invoke-SystemMaintenance',
        'Invoke-SystemPatch',
        'Get-SystemHealth'
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
            ReleaseNotes = 'Initial development version - GUI-based Windows maintenance tool'
        }
    }
}
