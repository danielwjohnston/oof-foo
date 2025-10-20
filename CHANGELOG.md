# Changelog

All notable changes to oof-foo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive logging system with configurable levels and retention
- Configuration file support (JSON-based, stored in AppData)
- System restore point creation before maintenance operations
- Confirmation dialogs for destructive operations
- Progress reporting for long-running operations
- Internet connectivity checking before updates
- Proper error handling with detailed error tracking
- Helper utilities for elevation, disk space, and system checks
- Windows Error Reports cleanup
- Delivery Optimization cache cleanup via DISM
- Download-only mode for updates
- Actual Windows Update installation (via PSWindows Update module)
- Actual winget package upgrades
- Actual Chocolatey package upgrades

### Changed
- Refactored SystemCleaner to use logging instead of Write-Host
- Refactored SystemUpdater to actually install updates (no longer stubs)
- Improved error handling throughout all modules
- Replaced magic numbers with configuration values
- Better tracking of space freed and operations performed
- More comprehensive cleanup operations

### Fixed
- GUI would freeze during long operations (partially - runspace implementation pending)
- No confirmation before destructive operations
- Commented-out update installation code
- Hard-coded values throughout codebase
- Minimal error handling
- No logging infrastructure
- No configuration persistence

### Security
- Added admin privilege checking before privileged operations
- Added restore point creation before destructive operations
- Added confirmation prompts for dangerous operations

## [0.1.0] - 2025-10-20

### Added
- Initial project structure
- PowerShell module framework (OofFoo.psd1/psm1)
- Basic Windows Forms GUI
- System updater module (stub)
- System maintenance module (partial implementation)
- Security patcher module (basic)
- System health reporter module
- Main launcher script (oof-foo.ps1)
- Build script (Build.ps1)
- Basic Pester tests
- MIT License
- README with project documentation
- CONTRIBUTING guidelines

### Known Issues
- GUI freezes during long operations (no async support yet)
- Update functions are stubs or incomplete
- No logging system
- No configuration persistence
- Limited error handling
- No CI/CD pipeline
- Test coverage is minimal

---

## Version History

- **v0.1.0** (2025-10-20) - Initial release with basic structure
- **Unreleased** - Major improvements to logging, configuration, error handling, and actual functionality
