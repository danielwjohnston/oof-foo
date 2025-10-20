# Contributing to oof-foo

Thank you for your interest in contributing to oof-foo! We welcome contributions from the community.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/oof-foo.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes
6. Commit and push
7. Create a Pull Request

## Development Setup

### Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Git
- Pester (for testing): `Install-Module -Name Pester -Scope CurrentUser`

### Project Structure

```
oof-foo/
├── src/OofFoo/          # Module source code
├── tests/               # Pester tests
├── docs/                # Documentation
├── build/               # Build scripts
└── oof-foo.ps1          # Main launcher
```

## Coding Standards

### PowerShell Style

- Use approved verbs for function names (Get-, Set-, Invoke-, etc.)
- Follow PascalCase for function names
- Use camelCase for variables
- Include comment-based help for all functions
- Use proper error handling with try/catch
- Keep functions focused and single-purpose

### Example Function Template

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description

    .DESCRIPTION
        Detailed description

    .PARAMETER ParameterName
        Parameter description

    .EXAMPLE
        Verb-Noun -ParameterName "value"

    .NOTES
        Additional notes
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ParameterName
    )

    try {
        # Implementation
    }
    catch {
        Write-Error "Error message: $_"
    }
}
```

## Testing

All new features and bug fixes should include tests.

### Running Tests

```powershell
# Run all tests
Invoke-Pester .\tests\

# Run specific test file
Invoke-Pester .\tests\OofFoo.Tests.ps1
```

### Writing Tests

Use Pester for all tests. Example:

```powershell
Describe "Feature Name" {
    Context "Specific Scenario" {
        It "Should do something" {
            # Test code
            $result | Should -Be $expected
        }
    }
}
```

## Pull Request Process

1. **Update Documentation**: Update README.md and other docs as needed
2. **Add Tests**: Include tests for new functionality
3. **Update CHANGELOG**: Add entry to CHANGELOG.md (if exists)
4. **Follow Conventions**: Ensure code follows project conventions
5. **Test Locally**: Run all tests before submitting
6. **Clear Description**: Provide clear PR description

### PR Title Format

- `feat: Add new feature`
- `fix: Fix bug in component`
- `docs: Update documentation`
- `test: Add tests for feature`
- `refactor: Refactor component`
- `style: Code style improvements`

## Feature Requests

Have an idea for oof-foo? Great!

1. Check existing issues first
2. Create a new issue with the "enhancement" label
3. Describe the feature and use case
4. Discuss with maintainers before implementing

## Bug Reports

Found a bug? Please report it!

### Bug Report Template

```
**Description**
Clear description of the bug

**Steps to Reproduce**
1. Step one
2. Step two
3. Step three

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- OS: Windows 10/11
- PowerShell Version: 5.1/7.x
- oof-foo Version: 0.1.0

**Screenshots**
If applicable

**Additional Context**
Any other relevant information
```

## Code Review Process

All submissions require review. We aim to:

- Review PRs within 48 hours
- Provide constructive feedback
- Maintain high code quality
- Keep the project maintainable

## Questions?

- Open an issue with the "question" label
- Check existing documentation
- Review closed issues for similar questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to oof-foo!**

*From "oof" to "phew!" together!* 💚 (00FF00)
