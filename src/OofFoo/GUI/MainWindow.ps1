function Start-OofFooGUI {
    <#
    .SYNOPSIS
        Launches the oof-foo GUI application with async operations

    .DESCRIPTION
        Starts the main Windows Forms GUI for the oof-foo system maintenance tool.
        Uses PowerShell runspaces for async operations to prevent UI freezing.
        From "oof" to "phew" in one click!

    .EXAMPLE
        Start-OofFooGUI
    #>

    [CmdletBinding()]
    param()

    # Load required assemblies
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Get module path for async operations
    $modulePath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    # Initialize runspace pool for async operations
    $script:runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
    $script:runspacePool.ApartmentState = "STA"
    $script:runspacePool.Open()
    $script:activeJobs = @{}

    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "oof-foo - System Maintenance Tool v0.2.0"
    $form.Size = New-Object System.Drawing.Size(900, 700)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

    # Create header panel
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Location = New-Object System.Drawing.Point(0, 0)
    $headerPanel.Size = New-Object System.Drawing.Size(900, 80)
    $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
    $form.Controls.Add($headerPanel)

    # Title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "oof-foo"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $titleLabel.AutoSize = $true
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $headerPanel.Controls.Add($titleLabel)

    # Subtitle
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "From 'oof' to 'phew!' - Async operations, no freezing!"
    $subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $subtitleLabel.Location = New-Object System.Drawing.Point(25, 55)
    $subtitleLabel.AutoSize = $true
    $subtitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $headerPanel.Controls.Add($subtitleLabel)

    # Tab control
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 90)
    $tabControl.Size = New-Object System.Drawing.Size(865, 520)
    $form.Controls.Add($tabControl)

    # Dashboard tab
    $dashboardTab = New-Object System.Windows.Forms.TabPage
    $dashboardTab.Text = "Dashboard"
    $tabControl.TabPages.Add($dashboardTab)

    # Status group
    $statusGroup = New-Object System.Windows.Forms.GroupBox
    $statusGroup.Text = "Operation Output"
    $statusGroup.Location = New-Object System.Drawing.Point(10, 10)
    $statusGroup.Size = New-Object System.Drawing.Size(830, 180)
    $dashboardTab.Controls.Add($statusGroup)

    # Status text
    $statusText = New-Object System.Windows.Forms.TextBox
    $statusText.Multiline = $true
    $statusText.ReadOnly = $true
    $statusText.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $statusText.Location = New-Object System.Drawing.Point(15, 25)
    $statusText.Size = New-Object System.Drawing.Size(800, 140)
    $statusText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $statusText.Text = "Ready. Operations run in background - no freezing!`r`nClick any button to start."
    $statusGroup.Controls.Add($statusText)

    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(25, 200)
    $progressBar.Size = New-Object System.Drawing.Size(810, 25)
    $progressBar.Visible = $false
    $dashboardTab.Controls.Add($progressBar)

    # Progress label
    $progressLabel = New-Object System.Windows.Forms.Label
    $progressLabel.Location = New-Object System.Drawing.Point(25, 230)
    $progressLabel.Size = New-Object System.Drawing.Size(810, 20)
    $progressLabel.Text = ""
    $progressLabel.Visible = $false
    $dashboardTab.Controls.Add($progressLabel)

    # Actions group
    $actionsGroup = New-Object System.Windows.Forms.GroupBox
    $actionsGroup.Text = "Quick Actions"
    $actionsGroup.Location = New-Object System.Drawing.Point(10, 260)
    $actionsGroup.Size = New-Object System.Drawing.Size(830, 220)
    $dashboardTab.Controls.Add($actionsGroup)

    # Timer for checking async jobs
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        $completedJobs = @()

        foreach ($jobId in @($script:activeJobs.Keys)) {
            $job = $script:activeJobs[$jobId]

            if ($job.Handle.IsCompleted) {
                try {
                    $result = $job.Runspace.EndInvoke($job.Handle)
                    $duration = ((Get-Date) - $job.StartTime).TotalSeconds

                    $job.StatusTextBox.Text = "✓ Completed in $([math]::Round($duration, 1))s`r`n`r`n"

                    if ($result) {
                        if ($result -is [string]) {
                            $job.StatusTextBox.AppendText($result)
                        } else {
                            $job.StatusTextBox.AppendText(($result | Out-String))
                        }
                    }

                    $job.ProgressLabel.Text = "Completed!"
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    $job.StatusTextBox.Text = "✗ Error: $errorMsg`r`n"
                    $job.ProgressLabel.Text = "Error occurred"
                }
                finally {
                    if ($job.Runspace) {
                        $job.Runspace.Dispose()
                    }
                    $job.ProgressBar.Visible = $false
                    $job.ProgressLabel.Visible = $false
                    $job.Button.Enabled = $true

                    $completedJobs += $jobId
                }
            }
        }

        foreach ($jobId in $completedJobs) {
            $script:activeJobs.Remove($jobId)
        }
    })
    $timer.Start()

    # Helper to run async
    $runAsync = {
        param($ScriptBlock, $StatusTextBox, $ProgressBar, $ProgressLabel, $Button, $ModulePath)

        $Button.Enabled = $false
        $ProgressBar.Visible = $true
        $ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        $ProgressLabel.Visible = $true
        $ProgressLabel.Text = "Working..."
        $StatusTextBox.Text = "Starting operation...`r`n"

        $runspace = [powershell]::Create()
        $runspace.RunspacePool = $script:runspacePool

        [void]$runspace.AddScript("Import-Module '$ModulePath\src\OofFoo\OofFoo.psd1' -Force")
        [void]$runspace.AddScript($ScriptBlock)

        $handle = $runspace.BeginInvoke()

        $jobId = [guid]::NewGuid().ToString()
        $script:activeJobs[$jobId] = @{
            Runspace = $runspace
            Handle = $handle
            StatusTextBox = $StatusTextBox
            ProgressBar = $ProgressBar
            ProgressLabel = $ProgressLabel
            Button = $Button
            StartTime = Get-Date
        }
    }

    # Health Check button
    $healthBtn = New-Object System.Windows.Forms.Button
    $healthBtn.Text = "Health Check"
    $healthBtn.Location = New-Object System.Drawing.Point(20, 30)
    $healthBtn.Size = New-Object System.Drawing.Size(150, 45)
    $healthBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $healthBtn.Add_Click({
        $script = {
            $result = Get-SystemHealth
            $output = "System Health Report:`r`n"
            $output += "═══════════════════════`r`n"
            $output += "Overall: $($result.OverallHealth)`r`n`r`n"
            $output += "System: $($result.System.OS)`r`n"
            $output += "Uptime: $($result.System.Uptime.Days)d $($result.System.Uptime.Hours)h`r`n`r`n"
            foreach ($drive in $result.Disk.Drives) {
                $output += "$($drive.Drive): $($drive.FreeGB)/$($drive.TotalGB) GB ($($drive.UsedPercent)%) [$($drive.Status)]`r`n"
            }
            if ($result.Warnings.Count -gt 0) {
                $output += "`r`nWarnings:`r`n"
                $result.Warnings | ForEach-Object { $output += "  ⚠ $_`r`n" }
            }
            return $output
        }
        & $runAsync $script $statusText $progressBar $progressLabel $healthBtn $modulePath
    })
    $actionsGroup.Controls.Add($healthBtn)

    # Updates button
    $updateBtn = New-Object System.Windows.Forms.Button
    $updateBtn.Text = "Check Updates"
    $updateBtn.Location = New-Object System.Drawing.Point(180, 30)
    $updateBtn.Size = New-Object System.Drawing.Size(150, 45)
    $updateBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $updateBtn.Add_Click({
        $script = {
            $result = Invoke-SystemUpdate -UpdateType All -DownloadOnly
            $output = "Update Check Results:`r`n`r`n"
            if ($result.WindowsUpdate) { $output += "Windows: $($result.WindowsUpdate.Message)`r`n" }
            if ($result.WinGet) { $output += "WinGet: $($result.WinGet.Message)`r`n" }
            if ($result.Chocolatey) { $output += "Chocolatey: $($result.Chocolatey.Message)`r`n" }
            return $output
        }
        & $runAsync $script $statusText $progressBar $progressLabel $updateBtn $modulePath
    })
    $actionsGroup.Controls.Add($updateBtn)

    # Maintenance button
    $maintenanceBtn = New-Object System.Windows.Forms.Button
    $maintenanceBtn.Text = "System Cleanup"
    $maintenanceBtn.Location = New-Object System.Drawing.Point(340, 30)
    $maintenanceBtn.Size = New-Object System.Drawing.Size(150, 45)
    $maintenanceBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $maintenanceBtn.Add_Click({
        $confirmation = [System.Windows.Forms.MessageBox]::Show(
            "Clean temp files and caches? This may delete data.",
            "Confirm",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes) {
            $script = {
                $result = Invoke-SystemMaintenance -DeepClean -SkipConfirmation
                $output = "Maintenance Complete!`r`n`r`n"
                $output += "Space freed: $($result.SpaceFreedMB) MB`r`n"
                $output += "Operations: $($result.Operations.Count)`r`n"
                $output += "Errors: $($result.Errors.Count)`r`n`r`n"
                $result.Operations | ForEach-Object {
                    $status = if ($_.Success) { "✓" } else { "✗" }
                    $output += "$status $($_.Name): $($_.Message)`r`n"
                }
                return $output
            }
            & $runAsync $script $statusText $progressBar $progressLabel $maintenanceBtn $modulePath
        }
    })
    $actionsGroup.Controls.Add($maintenanceBtn)

    # Full Maintenance button
    $fullBtn = New-Object System.Windows.Forms.Button
    $fullBtn.Text = "FULL MAINTENANCE"
    $fullBtn.Location = New-Object System.Drawing.Point(20, 90)
    $fullBtn.Size = New-Object System.Drawing.Size(220, 55)
    $fullBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $fullBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 200, 0)
    $fullBtn.ForeColor = [System.Drawing.Color]::White
    $fullBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $fullBtn.Add_Click({
        $confirmation = [System.Windows.Forms.MessageBox]::Show(
            "Run full maintenance (updates + cleanup + patches)?`nThis may take 30+ minutes.",
            "Confirm Full Maintenance",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes) {
            $script = {
                $output = "=== FULL MAINTENANCE ===`r`n`r`n"
                try {
                    $output += "1. Health Check (Before)...`r`n"
                    $before = Get-SystemHealth
                    $output += "   Status: $($before.OverallHealth)`r`n`r`n"

                    $output += "2. System Updates...`r`n"
                    $updates = Invoke-SystemUpdate -UpdateType All -SkipConfirmation
                    $output += "   $($updates.WindowsUpdate.Message)`r`n`r`n"

                    $output += "3. Maintenance...`r`n"
                    $maint = Invoke-SystemMaintenance -DeepClean -SkipConfirmation
                    $output += "   Freed: $($maint.SpaceFreedMB) MB`r`n`r`n"

                    $output += "4. Security Patches...`r`n"
                    $patch = Invoke-SystemPatch
                    $output += "   Defender: $($patch.DefenderUpdates)`r`n`r`n"

                    $output += "5. Health Check (After)...`r`n"
                    $after = Get-SystemHealth
                    $output += "   Status: $($after.OverallHealth)`r`n`r`n"

                    $output += "=== COMPLETE ===`r`n"
                } catch {
                    $output += "`r`n✗ ERROR: $_`r`n"
                }
                return $output
            }
            & $runAsync $script $statusText $progressBar $progressLabel $fullBtn $modulePath
        }
    })
    $actionsGroup.Controls.Add($fullBtn)

    # View Logs button
    $logsBtn = New-Object System.Windows.Forms.Button
    $logsBtn.Text = "View Logs"
    $logsBtn.Location = New-Object System.Drawing.Point(250, 90)
    $logsBtn.Size = New-Object System.Drawing.Size(120, 40)
    $logsBtn.Add_Click({
        try {
            $logPath = Get-OofFooLogPath
            if (Test-Path $logPath) {
                Start-Process notepad.exe $logPath
            } else {
                [System.Windows.Forms.MessageBox]::Show("No logs yet.", "Logs")
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error")
        }
    })
    $actionsGroup.Controls.Add($logsBtn)

    # Settings button
    $settingsBtn = New-Object System.Windows.Forms.Button
    $settingsBtn.Text = "Settings"
    $settingsBtn.Location = New-Object System.Drawing.Point(380, 90)
    $settingsBtn.Size = New-Object System.Drawing.Size(110, 40)
    $settingsBtn.Add_Click({
        try {
            $configPath = Get-OofFooConfigPath
            if (-not (Test-Path $configPath)) {
                Set-OofFooConfig -Config (Get-OofFooDefaultConfig)
            }
            Start-Process notepad.exe $configPath
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error")
        }
    })
    $actionsGroup.Controls.Add($settingsBtn)

    # About tab
    $aboutTab = New-Object System.Windows.Forms.TabPage
    $aboutTab.Text = "About"
    $tabControl.TabPages.Add($aboutTab)

    $aboutText = New-Object System.Windows.Forms.TextBox
    $aboutText.Multiline = $true
    $aboutText.ReadOnly = $true
    $aboutText.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $aboutText.Location = New-Object System.Drawing.Point(20, 20)
    $aboutText.Size = New-Object System.Drawing.Size(810, 460)
    $aboutText.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $aboutText.Text = @"
oof-foo v0.2.0

All-in-one Windows system maintenance tool.
From 'oof' to 'phew!' - System maintenance made easy.

ABOUT THE NAME:
• 00FF00 - Bright green, representing system health
• oof.foo - Simple, catchy, memorable
• 'oof-phew' - From problem to solution

NEW IN v0.2.0:
✓ ASYNC OPERATIONS - No more freezing!
✓ Comprehensive logging system
✓ Configuration file support
✓ Actual Windows Update installation
✓ System restore point creation
✓ Confirmation dialogs
✓ Progress reporting
✓ Much better error handling

FEATURES:
• Windows Updates (PSWindowsUpdate)
• winget & Chocolatey package updates
• Security patching
• Disk cleanup & optimization
• System health monitoring
• Comprehensive logging
• Configurable settings

LOGS & CONFIG:
Logs: `$env:APPDATA\OofFoo\Logs\
Config: `$env:APPDATA\OofFoo\config.json

Copyright (c) 2025
https://oof.foo
"@
    $aboutTab.Controls.Add($aboutText)

    # Status bar
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusBarLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusBarLabel.Text = "Ready | oof.foo v0.2.0 | Async GUI - No Freezing!"
    $statusBar.Items.Add($statusBarLabel) | Out-Null
    $form.Controls.Add($statusBar)

    # Cleanup on close
    $form.Add_FormClosing({
        $timer.Stop()
        $timer.Dispose()

        if ($script:activeJobs.Count -gt 0) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Operations running. Force close?",
                "Confirm",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                $_.Cancel = $true
                return
            }
        }

        foreach ($job in $script:activeJobs.Values) {
            try { $job.Runspace.Dispose() } catch {}
        }

        if ($script:runspacePool) {
            $script:runspacePool.Close()
            $script:runspacePool.Dispose()
        }
    })

    # Show form
    [void]$form.ShowDialog()
}
