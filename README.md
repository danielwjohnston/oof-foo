# oof-foo

**From "oof" to "phew!" - System maintenance made easy**

![Version](https://img.shields.io/badge/version-0.3.0-brightgreen)
![Status](https://img.shields.io/badge/status-beta-blue)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

> ✨ **BETA SOFTWARE**: oof-foo is feature-complete with async GUI! Core functionality is solid. Ready for testing in non-critical environments.

---

## Development Status

**Current Version:** 0.3.0 (Beta)

**What Works:**
- ✅ **Async GUI - No freezing!** (PowerShell runspaces)
- ✅ **Scheduled task automation** (automated maintenance)
- ✅ **Advanced cleanup** (Windows.old, driver store, thumbnails)
- ✅ Command-line maintenance operations
- ✅ Actual Windows Update installation (via PSWindowsUpdate)
- ✅ winget and Chocolatey package upgrades
- ✅ Comprehensive logging system
- ✅ Configuration file support
- ✅ System restore point creation
- ✅ Temp file cleanup, cache clearing
- ✅ Windows Error Reports cleanup
- ✅ DISM-based delivery optimization cleanup
- ✅ System health reporting
- ✅ Integration test suite

**Known Limitations:**
- ⚠️ No MSI installer yet (planned for v1.0)
- ⚠️ GUI could use more polish (functional but basic)
- ⚠️ No telemetry/analytics

**Roadmap:** See [CHANGELOG.md](CHANGELOG.md) for detailed version history and upcoming features.

---

## About

**oof-foo** is an all-in-one Windows system maintenance, updating, and patching tool designed to keep your computer running smoothly with minimal effort.

### The Name

- **00FF00** - Bright green (#00FF00), representing healthy system status
- **oof.foo** - Simple, catchy, memorable domain name
- **"oof-phew"** - Captures the experience: from problem ("oof!") to solution ("phew!")

---

## Features

### System Updates
- Windows Update management (requires PSWindowsUpdate module)
- winget package upgrades
- Chocolatey package upgrades (if installed)
- Download-only mode available
- Internet connectivity checking

### Security & Patching
- Security patch prioritization
- Windows Defender signature updates
- Firewall status monitoring
- Security health checks

### System Maintenance
- Disk cleanup and optimization
- Temporary file removal
- Cache clearing (Windows, browsers)
- Recycle Bin management
- Windows Update cache cleanup

### Health Monitoring
- Disk space monitoring
- Memory usage tracking
- System diagnostics
- Update history tracking
- Comprehensive health reports

### User Interface
- Basic Windows Forms GUI
- Dashboard with quick actions
- Health check display
- ⚠️ **Note:** GUI currently freezes during operations (will be fixed in next release)

---

## Installation

### Quick Start

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/danielwjohnston/oof-foo.git
   cd oof-foo
   ```

2. **Import the module:**
   ```powershell
   Import-Module .\src\OofFoo\OofFoo.psd1
   ```

3. **Launch the GUI:**
   ```powershell
   Start-OofFooGUI
   ```

### System Requirements

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrator privileges (for system updates and maintenance)
- Internet connection (for updates)

### Optional Components

- **PSWindowsUpdate** module (automatically installed if needed)
- **winget** (Windows Package Manager) - recommended
- **Chocolatey** - optional

---

## Usage

### GUI Mode (Recommended)

Launch the graphical interface:

```powershell
Start-OofFooGUI
```

The GUI provides:
- **Dashboard** - Quick actions and system status
- **Updates** - Manage Windows and application updates
- **Maintenance** - Disk cleanup and optimization
- **Settings** - Configure schedules and preferences
- **About** - Information about oof-foo

### Command Line Mode

For automation and scripting:

```powershell
# Run full system maintenance
Invoke-SystemUpdate -UpdateType All
Invoke-SystemMaintenance -DeepClean
Invoke-SystemPatch

# Get system health report
Get-SystemHealth -Detailed

# Specific tasks
Invoke-SystemUpdate -UpdateType WinGet
Invoke-SystemMaintenance -IncludeLogs
```

### Examples

**Quick health check:**
```powershell
Get-SystemHealth
```

**Full maintenance run:**
```powershell
Import-Module .\src\OofFoo\OofFoo.psd1
Invoke-SystemUpdate -UpdateType All
Invoke-SystemMaintenance -DeepClean -IncludeLogs
Invoke-SystemPatch -IncludeThirdParty
```

**Scheduled task (run weekly):**
```powershell
# Create scheduled task to run oof-foo weekly
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\path\to\oof-foo.ps1"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
Register-ScheduledTask -TaskName "oof-foo Maintenance" -Action $action -Trigger $trigger -RunLevel Highest
```

---

## Project Structure

```
oof-foo/
├── src/
│   └── OofFoo/
│       ├── OofFoo.psd1              # Module manifest
│       ├── OofFoo.psm1              # Main module file
│       ├── GUI/
│       │   └── MainWindow.ps1       # Windows Forms GUI
│       ├── Modules/
│       │   ├── Updater/
│       │   │   └── SystemUpdater.ps1      # Update management
│       │   ├── Patcher/
│       │   │   └── SecurityPatcher.ps1    # Security patching
│       │   ├── Maintenance/
│       │   │   └── SystemCleaner.ps1      # System cleanup
│       │   └── Reporter/
│       │       └── SystemHealth.ps1       # Health reporting
│       └── Utils/                   # Utility functions
├── tests/                           # Pester tests
├── docs/                            # Documentation
├── build/                           # Build scripts
├── oof-foo.ps1                      # Main launcher script
└── README.md                        # This file
```

---

## Development

### Building from Source

```powershell
# Run build script
.\build\Build.ps1
```

### Running Tests

```powershell
# Install Pester if needed
Install-Module -Name Pester -Force -Scope CurrentUser

# Run tests
Invoke-Pester .\tests\
```

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Roadmap

### v0.1.0 (Current)
- [x] Core GUI framework
- [x] Basic update management
- [x] System maintenance functions
- [x] Security patching
- [x] Health reporting

### v0.2.0 (Planned)
- [ ] Scheduled task automation
- [ ] Email/notification system
- [ ] Detailed logging
- [ ] Settings persistence
- [ ] Custom maintenance profiles

### v0.3.0 (Future)
- [ ] Remote system management
- [ ] Multiple computer support
- [ ] Advanced reporting
- [ ] Plugin system
- [ ] Web dashboard

### v1.0.0 (Future)
- [ ] Full feature set
- [ ] Comprehensive documentation
- [ ] Installer package (.msi)
- [ ] Auto-update functionality
- [ ] Commercial support options

---

## FAQ

**Q: Does oof-foo require administrator privileges?**
A: Yes, most maintenance tasks (Windows Update, disk cleanup, etc.) require admin rights.

**Q: Is it safe to run?**
A: oof-foo uses built-in Windows tools and well-established PowerShell modules. All operations are logged and can be reviewed.

**Q: Can I schedule automatic maintenance?**
A: Yes, you can create Windows scheduled tasks to run oof-foo regularly.

**Q: Does it work on Windows Server?**
A: Yes, oof-foo works on Windows Server 2016 and later.

**Q: What about Windows 7/8?**
A: Windows 7/8 are not officially supported, though basic functions may work.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Support

- **Website:** https://oof.foo
- **Issues:** https://github.com/danielwjohnston/oof-foo/issues
- **Email:** support@oof.foo

---

## Acknowledgments

- Built with PowerShell and Windows Forms
- Inspired by the need for simple, effective system maintenance
- Named after a favorite color (00FF00) and a great domain

---

**Made with 💚 (00FF00) by danielwjohnston**

*From "oof" to "phew!" in one click!*
