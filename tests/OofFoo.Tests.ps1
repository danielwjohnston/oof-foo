# Pester tests for oof-foo module

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "..\src\OofFoo\OofFoo.psd1"
    Import-Module $modulePath -Force
}

Describe "OofFoo Module" {
    Context "Module Loading" {
        It "Should import the module successfully" {
            $module = Get-Module -Name OofFoo
            $module | Should -Not -BeNullOrEmpty
        }

        It "Should have correct module version" {
            $module = Get-Module -Name OofFoo
            $module.Version.ToString() | Should -Be "0.1.0"
        }
    }

    Context "Exported Functions" {
        It "Should export Start-OofFooGUI function" {
            Get-Command -Name Start-OofFooGUI -Module OofFoo | Should -Not -BeNullOrEmpty
        }

        It "Should export Invoke-SystemUpdate function" {
            Get-Command -Name Invoke-SystemUpdate -Module OofFoo | Should -Not -BeNullOrEmpty
        }

        It "Should export Invoke-SystemMaintenance function" {
            Get-Command -Name Invoke-SystemMaintenance -Module OofFoo | Should -Not -BeNullOrEmpty
        }

        It "Should export Invoke-SystemPatch function" {
            Get-Command -Name Invoke-SystemPatch -Module OofFoo | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-SystemHealth function" {
            Get-Command -Name Get-SystemHealth -Module OofFoo | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Get-SystemHealth" {
    Context "Basic Health Check" {
        It "Should return a health report object" {
            # Note: This will only run on Windows
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
                $report = Get-SystemHealth
                $report | Should -Not -BeNullOrEmpty
                $report.OverallHealth | Should -Not -BeNullOrEmpty
            }
            else {
                Set-ItResult -Skipped -Because "Test requires Windows"
            }
        }

        It "Should include system information" {
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
                $report = Get-SystemHealth
                $report.System | Should -Not -BeNullOrEmpty
                $report.System.OS | Should -Not -BeNullOrEmpty
            }
            else {
                Set-ItResult -Skipped -Because "Test requires Windows"
            }
        }
    }
}

Describe "Function Help" {
    Context "Help Documentation" {
        It "Start-OofFooGUI should have help documentation" {
            $help = Get-Help Start-OofFooGUI
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Invoke-SystemUpdate should have help documentation" {
            $help = Get-Help Invoke-SystemUpdate
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Get-SystemHealth should have help documentation" {
            $help = Get-Help Get-SystemHealth
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module OofFoo -Force -ErrorAction SilentlyContinue
}
