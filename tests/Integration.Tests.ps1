# Integration tests for oof-foo module

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "..\src\OofFoo\OofFoo.psd1"
    Import-Module $modulePath -Force
}

Describe "Configuration System Integration" {
    Context "Config File Operations" {
        It "Should create default config when none exists" {
            $config = Get-OofFooConfig
            $config | Should -Not -BeNullOrEmpty
            $config.Version | Should -Be "0.1.0"
        }

        It "Should have all required config sections" {
            $config = Get-OofFooConfig
            $config.Logging | Should -Not -BeNullOrEmpty
            $config.Maintenance | Should -Not -BeNullOrEmpty
            $config.Updates | Should -Not -BeNullOrEmpty
            $config.GUI | Should -Not -BeNullOrEmpty
        }

        It "Should save and load config correctly" {
            $config = Get-OofFooConfig
            $config.Logging.Level = "Verbose"
            Set-OofFooConfig -Config $config

            $reloaded = Get-OofFooConfig
            $reloaded.Logging.Level | Should -Be "Verbose"
        }
    }
}

Describe "Logging System Integration" {
    Context "Log File Operations" {
        It "Should write log entries" {
            Write-OofFooLog "Test log entry" -Level Information
            $logPath = Get-OofFooLogPath

            if (Test-Path $logPath) {
                $logs = Get-Content $logPath
                $logs | Should -Contain { $_ -match "Test log entry" }
            }
        }

        It "Should retrieve recent logs" {
            Write-OofFooLog "Integration test log" -Level Information
            $logs = Get-OofFooLogs -Last 10

            $logs | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "System Helpers Integration" {
    Context "Administrator Check" {
        It "Should detect admin status" {
            $isAdmin = Test-OofFooAdministrator
            $isAdmin | Should -BeOfType [bool]
        }
    }

    Context "Disk Space Check" {
        It "Should get free disk space" {
            $space = Get-OofFooFreeSpace -DriveLetter C
            $space | Should -Not -BeNullOrEmpty
            $space.FreeSpaceGB | Should -BeGreaterThan 0
            $space.TotalSpaceGB | Should -BeGreaterThan 0
        }
    }

    Context "Online Check" {
        It "Should check internet connectivity" {
            $online = Test-OofFooOnline
            $online | Should -BeOfType [bool]
        }
    }

    Context "Readable Size Conversion" {
        It "Should convert bytes to readable format" {
            $result = ConvertTo-OofFooReadableSize -Bytes 1073741824
            $result | Should -Match "GB"
        }

        It "Should handle small sizes" {
            $result = ConvertTo-OofFooReadableSize -Bytes 1024
            $result | Should -Match "KB"
        }
    }
}

Describe "System Health Integration" {
    Context "Health Check Execution" {
        It "Should generate health report" {
            $health = Get-SystemHealth
            $health | Should -Not -BeNullOrEmpty
            $health.OverallHealth | Should -Not -BeNullOrEmpty
        }

        It "Should include system information" {
            $health = Get-SystemHealth
            $health.System | Should -Not -BeNullOrEmpty
            $health.System.OS | Should -Not -BeNullOrEmpty
        }

        It "Should include disk information" {
            $health = Get-SystemHealth
            $health.Disk | Should -Not -BeNullOrEmpty
            $health.Disk.Drives | Should -Not -BeNullOrEmpty
        }

        It "Should include memory information" {
            $health = Get-SystemHealth
            $health.Memory | Should -Not -BeNullOrEmpty
            $health.Memory.TotalGB | Should -BeGreaterThan 0
        }
    }
}

Describe "Scheduled Task Functions" {
    Context "Task Query" {
        It "Should query scheduled tasks without error" {
            { Get-OofFooScheduledTask } | Should -Not -Throw
        }
    }

    Context "Task Creation (Admin Required)" {
        It "Should validate parameters" {
            $params = @{
                Frequency = "Weekly"
                Time = "03:00"
                DayOfWeek = "Sunday"
                MaintenanceType = "HealthCheckOnly"
            }

            # Just validate the command exists and accepts parameters
            $cmd = Get-Command New-OofFooScheduledTask
            $cmd | Should -Not -BeNullOrEmpty
            $cmd.Parameters.Keys | Should -Contain "Frequency"
            $cmd.Parameters.Keys | Should -Contain "MaintenanceType"
        }
    }
}

Describe "Module Integration" {
    Context "Module Loading" {
        It "Should export all required functions" {
            $module = Get-Module OofFoo
            $module.ExportedFunctions.Keys | Should -Contain "Start-OofFooGUI"
            $module.ExportedFunctions.Keys | Should -Contain "Get-OofFooConfig"
            $module.ExportedFunctions.Keys | Should -Contain "Write-OofFooLog"
            $module.ExportedFunctions.Keys | Should -Contain "Test-OofFooAdministrator"
        }

        It "Should have correct module version" {
            $module = Get-Module OofFoo
            $module.Version.ToString() | Should -Be "0.2.0"
        }
    }

    Context "Function Availability" {
        It "Should have help for all exported functions" {
            $module = Get-Module OofFoo
            foreach ($func in $module.ExportedFunctions.Keys) {
                $help = Get-Help $func
                $help.Synopsis | Should -Not -BeNullOrEmpty
            }
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Module OofFoo -Force -ErrorAction SilentlyContinue
}
