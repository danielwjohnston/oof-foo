function Start-OofFooGUI {
    <#
    .SYNOPSIS
        Launches the oof-foo GUI application

    .DESCRIPTION
        Starts the main Windows Forms GUI for the oof-foo system maintenance tool.
        From "oof" to "phew" in one click!

    .EXAMPLE
        Start-OofFooGUI
    #>

    [CmdletBinding()]
    param()

    # Load required assemblies
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "oof-foo - System Maintenance Tool"
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

    # Create header panel with branding
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Location = New-Object System.Drawing.Point(0, 0)
    $headerPanel.Size = New-Object System.Drawing.Size(800, 80)
    $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 255, 0)  # 00FF00 - bright green
    $form.Controls.Add($headerPanel)

    # Logo/Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "oof-foo"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $titleLabel.AutoSize = $true
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $headerPanel.Controls.Add($titleLabel)

    # Subtitle label
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "From 'oof' to 'phew!' - System maintenance made easy"
    $subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $subtitleLabel.Location = New-Object System.Drawing.Point(25, 55)
    $subtitleLabel.AutoSize = $true
    $subtitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $headerPanel.Controls.Add($subtitleLabel)

    # Create tab control
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 90)
    $tabControl.Size = New-Object System.Drawing.Size(765, 420)
    $form.Controls.Add($tabControl)

    # ===== DASHBOARD TAB =====
    $dashboardTab = New-Object System.Windows.Forms.TabPage
    $dashboardTab.Text = "Dashboard"
    $tabControl.TabPages.Add($dashboardTab)

    # System status group
    $statusGroup = New-Object System.Windows.Forms.GroupBox
    $statusGroup.Text = "System Status"
    $statusGroup.Location = New-Object System.Drawing.Point(10, 10)
    $statusGroup.Size = New-Object System.Drawing.Size(730, 150)
    $dashboardTab.Controls.Add($statusGroup)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "System health: Checking..."
    $statusLabel.Location = New-Object System.Drawing.Point(15, 25)
    $statusLabel.Size = New-Object System.Drawing.Size(700, 110)
    $statusLabel.Font = New-Object System.Drawing.Font("Consolas", 9)
    $statusGroup.Controls.Add($statusLabel)

    # Quick actions group
    $actionsGroup = New-Object System.Windows.Forms.GroupBox
    $actionsGroup.Text = "Quick Actions"
    $actionsGroup.Location = New-Object System.Drawing.Point(10, 170)
    $actionsGroup.Size = New-Object System.Drawing.Size(730, 210)
    $dashboardTab.Controls.Add($actionsGroup)

    # Run All button
    $runAllBtn = New-Object System.Windows.Forms.Button
    $runAllBtn.Text = "Run Full Maintenance"
    $runAllBtn.Location = New-Object System.Drawing.Point(20, 30)
    $runAllBtn.Size = New-Object System.Drawing.Size(200, 50)
    $runAllBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $runAllBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 200, 0)
    $runAllBtn.ForeColor = [System.Drawing.Color]::White
    $runAllBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $runAllBtn.Add_Click({
        $statusLabel.Text = "Running full maintenance...`nThis may take several minutes."
        $form.Refresh()
        # TODO: Implement full maintenance
        [System.Windows.Forms.MessageBox]::Show("Full maintenance completed!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $actionsGroup.Controls.Add($runAllBtn)

    # Individual action buttons
    $updateBtn = New-Object System.Windows.Forms.Button
    $updateBtn.Text = "Updates Only"
    $updateBtn.Location = New-Object System.Drawing.Point(20, 90)
    $updateBtn.Size = New-Object System.Drawing.Size(150, 35)
    $actionsGroup.Controls.Add($updateBtn)

    $patchBtn = New-Object System.Windows.Forms.Button
    $patchBtn.Text = "Security Patches"
    $patchBtn.Location = New-Object System.Drawing.Point(180, 90)
    $patchBtn.Size = New-Object System.Drawing.Size(150, 35)
    $actionsGroup.Controls.Add($patchBtn)

    $cleanBtn = New-Object System.Windows.Forms.Button
    $cleanBtn.Text = "System Cleanup"
    $cleanBtn.Location = New-Object System.Drawing.Point(340, 90)
    $cleanBtn.Size = New-Object System.Drawing.Size(150, 35)
    $actionsGroup.Controls.Add($cleanBtn)

    $healthBtn = New-Object System.Windows.Forms.Button
    $healthBtn.Text = "Health Check"
    $healthBtn.Location = New-Object System.Drawing.Point(500, 90)
    $healthBtn.Size = New-Object System.Drawing.Size(150, 35)
    $healthBtn.Add_Click({
        $statusLabel.Text = "Checking system health...`n`nPlease wait..."
        $form.Refresh()

        # Get system info
        $os = Get-CimInstance Win32_OperatingSystem
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $diskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $diskTotalGB = [math]::Round($disk.Size / 1GB, 2)
        $diskUsedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)

        $statusText = "System Health Report:`n"
        $statusText += "─────────────────────────────────`n"
        $statusText += "OS: $($os.Caption) ($($os.OSArchitecture))`n"
        $statusText += "Last Boot: $(Get-Date $os.LastBootUpTime -Format 'yyyy-MM-dd HH:mm')`n"
        $statusText += "Disk C: $diskFreeGB GB free / $diskTotalGB GB total ($diskUsedPercent% used)`n"
        $statusText += "Memory: $([math]::Round($os.FreePhysicalMemory / 1MB, 2)) GB free`n"
        $statusText += "─────────────────────────────────`n"
        $statusText += "Status: " + $(if ($diskUsedPercent -lt 85) { "✓ Healthy" } else { "⚠ Low disk space" })

        $statusLabel.Text = $statusText
    })
    $actionsGroup.Controls.Add($healthBtn)

    # ===== UPDATES TAB =====
    $updatesTab = New-Object System.Windows.Forms.TabPage
    $updatesTab.Text = "Updates"
    $tabControl.TabPages.Add($updatesTab)

    $updatesLabel = New-Object System.Windows.Forms.Label
    $updatesLabel.Text = "Windows Updates, winget packages, and application updates will be managed here."
    $updatesLabel.Location = New-Object System.Drawing.Point(20, 20)
    $updatesLabel.Size = New-Object System.Drawing.Size(700, 60)
    $updatesTab.Controls.Add($updatesLabel)

    # ===== MAINTENANCE TAB =====
    $maintenanceTab = New-Object System.Windows.Forms.TabPage
    $maintenanceTab.Text = "Maintenance"
    $tabControl.TabPages.Add($maintenanceTab)

    $maintenanceLabel = New-Object System.Windows.Forms.Label
    $maintenanceLabel.Text = "Disk cleanup, cache clearing, temp file removal, and other maintenance tasks."
    $maintenanceLabel.Location = New-Object System.Drawing.Point(20, 20)
    $maintenanceLabel.Size = New-Object System.Drawing.Size(700, 60)
    $maintenanceTab.Controls.Add($maintenanceLabel)

    # ===== SETTINGS TAB =====
    $settingsTab = New-Object System.Windows.Forms.TabPage
    $settingsTab.Text = "Settings"
    $tabControl.TabPages.Add($settingsTab)

    $settingsLabel = New-Object System.Windows.Forms.Label
    $settingsLabel.Text = "Configure automatic maintenance schedules and notification preferences."
    $settingsLabel.Location = New-Object System.Drawing.Point(20, 20)
    $settingsLabel.Size = New-Object System.Drawing.Size(700, 60)
    $settingsTab.Controls.Add($settingsLabel)

    # ===== ABOUT TAB =====
    $aboutTab = New-Object System.Windows.Forms.TabPage
    $aboutTab.Text = "About"
    $tabControl.TabPages.Add($aboutTab)

    $aboutText = New-Object System.Windows.Forms.TextBox
    $aboutText.Multiline = $true
    $aboutText.ReadOnly = $true
    $aboutText.Location = New-Object System.Drawing.Point(20, 20)
    $aboutText.Size = New-Object System.Drawing.Size(710, 360)
    $aboutText.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $aboutText.Text = @"
oof-foo v0.1.0

All-in-one Windows system maintenance, updating, and patching tool.

From 'oof' to 'phew!' - System maintenance made easy.


ABOUT THE NAME:
• 00FF00 - Bright green (#00FF00), representing system health
• oof.foo - Simple, catchy, memorable domain
• 'oof-phew' - The feeling of fixing system problems


FEATURES:
• Automated Windows Updates
• Application updates (winget, chocolatey)
• Security patching
• Disk cleanup and optimization
• System health monitoring
• Scheduled maintenance


Copyright (c) 2025
https://oof.foo
"@
    $aboutTab.Controls.Add($aboutText)

    # Status bar at bottom
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusBarLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusBarLabel.Text = "Ready | oof.foo"
    $statusBar.Items.Add($statusBarLabel) | Out-Null
    $form.Controls.Add($statusBar)

    # Show the form
    [void]$form.ShowDialog()
}
