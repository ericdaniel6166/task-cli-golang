# Distribution Guide

This guide documents how task-cli is packaged, distributed, and installed across Linux, macOS, and Windows platforms.

## Overview

Task-cli uses a multi-platform distribution model powered by GoReleaser. Each release produces:
- **8 platform/architecture combinations**: Linux, macOS, Windows × amd64, arm64
- **Tarball archives** (.tar.gz for Unix, .zip for Windows)
- **SHA256 checksums** for integrity verification
- **Automated install/uninstall scripts** with OS and architecture detection

This approach ensures users on any platform can install task-cli with a single command:

```bash
# Universal install for Linux/macOS
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/install.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/install-windows.ps1 | iex
```

## Build Configuration (GoReleaser)

### Configuration File: `.goreleaser.yaml`

```yaml
version: 2
project_name: task-cli

builds:
  - env: [CGO_ENABLED=0]          # Pure Go, no C dependencies
    goos: [linux, windows, darwin] # Target OSes
    goarch: [amd64, arm64]         # Target architectures
    main: ./main.go
    ldflags:
      - -s -w                      # Strip symbols (smaller binary)
      - -X main.version={{.Version}} # Inject version string
```

### Build Targets

GoReleaser generates 8 release artifacts:

| OS | Architecture | Archive Format | Size |
|---|---|---|---|
| Linux | amd64 | task-cli_v*_linux_amd64.tar.gz | 8-10MB |
| Linux | arm64 | task-cli_v*_linux_arm64.tar.gz | 8-10MB |
| macOS | amd64 | task-cli_v*_darwin_amd64.tar.gz | 8-10MB |
| macOS | arm64 | task-cli_v*_darwin_arm64.tar.gz | 8-10MB |
| Windows | amd64 | task-cli_v*_windows_amd64.zip | 8-10MB |
| Windows | arm64 | task-cli_v*_windows_arm64.zip | 8-10MB |

Plus: `checksums.txt` (SHA256 hashes for all artifacts)

### Build Features

- **CGO_ENABLED=0**: Pure Go compilation—no C compiler required
- **Symbol stripping** (-s -w flags): Reduces binary size without affecting functionality
- **Version injection**: Build-time version string available to application
- **Automatic changelog**: Excluded "docs:" and "test:" commits from release notes

## Installation System Architecture

### Install Script Hierarchy

```
User runs: install.sh
  ↓ (OS detection)
  ├─→ Linux detected → install-linux.sh
  ├─→ macOS detected → install-macos.sh
  └─→ Windows detected → Prompt for PowerShell install-windows.ps1
```

### Universal Dispatcher: `scripts/install.sh`

**Purpose**: Auto-detect OS and delegate to platform-specific script.

**Behavior**:
1. Detects OS via `uname -s` (Linux, macOS, Windows Git Bash)
2. Downloads platform-specific script to temp file
3. Executes script with bash
4. Cleans up temp file (trap EXIT)

**Why separate from platform scripts**: Allows single distribution URL while supporting all platforms.

### Linux Installation: `scripts/install-linux.sh`

**Flow**:
1. **Architecture Detection**
   - `uname -m` → x86_64 (amd64) or aarch64/arm64
   - Exits with error if unsupported

2. **Version Resolution**
   - Fetch latest from GitHub API: `/repos/{repo}/releases/latest`
   - Error handling: Set VERSION env var to override (useful during rate limiting)

3. **Download & Verification**
   - Constructs archive URL: `https://github.com/{repo}/releases/download/{version}/{archive}`
   - Downloads checksums.txt
   - Verifies with: `sha256sum -c checksums.txt`
   - Fails immediately if checksum mismatch (prevents running damaged binary)

4. **Extraction & Installation**
   - Extracts tarball to temp directory
   - Detects if /usr/local/bin requires sudo (not root)
   - Installs to INSTALL_DIR (default: /usr/local/bin)
   - Sets permissions: chmod 755

5. **Post-Install Guidance**
   - Checks if INSTALL_DIR in $PATH
   - If not, suggests PATH export command

**Environment Variables**:
- `INSTALL_DIR` - Override installation location (default: /usr/local/bin)
- `VERSION` - Explicit version (format: v1.2.3) if GitHub API fails

**Example with custom install directory**:
```bash
INSTALL_DIR=~/.local/bin install-linux.sh
```

### macOS Installation: `scripts/install-macos.sh`

Functionally identical to Linux script with platform-appropriate paths:
- Same architecture detection (x86_64, arm64)
- Same checksum verification
- Same sudoer awareness for /usr/local/bin
- Compatible with both Intel and Apple Silicon (M1/M2/M3)

### Windows Installation: `scripts/install-windows.ps1`

**Requirements**: PowerShell 5.1+ (built-in on Windows 10+)

**Flow**:
1. **Architecture Detection**
   - Uses `[System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture`
   - Maps: X64 → amd64, Arm64 → arm64

2. **Version Resolution**
   - GitHub API call via `Invoke-RestMethod`
   - Returns tag_name automatically

3. **Download & Verification**
   - Constructs URLs for .zip archive and checksums.txt
   - Downloads to temp folder
   - Computes SHA256 and compares with checksums.txt

4. **Installation & PATH Update**
   - Extracts .zip to InstallDir (default: $LOCALAPPDATA\task-cli)
   - Updates user PATH via registry (HKCU:\Environment\Path)
   - Prompts user to restart terminal for PATH to take effect

5. **Installation Validation**
   - Checks that binary exists and is executable
   - Provides helpful PATH-related warnings

**Execution Policy**:
```powershell
# May need to run once to allow remote scripts
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Installation Directory**:
- Default: `$env:LOCALAPPDATA\task-cli` (typically C:\Users\{username}\AppData\Local\task-cli)
- No admin required (user-level installation)

**Custom installation**:
```powershell
irm https://raw.githubusercontent.com/.../install-windows.ps1 | iex -ArgumentList @{InstallDir = "C:\tools"}
```

## Uninstallation System

### Linux/macOS: `scripts/uninstall-linux.sh` and `scripts/uninstall-macos.sh`

**Behavior**:
1. Removes binary from installation location
2. Removes plugin directory: `~/.task-cli/bin/`
3. Option to purge data and config (--purge flag):
   - `~/.task-cli/tasks.db` (database)
   - `~/.task-cli.yaml` (config file)

**Basic uninstall** (keep data):
```bash
curl -fsSL https://raw.githubusercontent.com/.../uninstall-linux.sh | bash
```

**Complete removal** (delete all data):
```bash
curl -fsSL https://raw.githubusercontent.com/.../uninstall-linux.sh | bash -s -- --purge
```

### Windows: `scripts/uninstall-windows.ps1`

**Behavior**:
1. Removes binary from InstallDir
2. Removes plugin directory: `$LOCALAPPDATA\task-cli\bin\`
3. Removes PATH entry from registry
4. Option to purge user data (--Purge switch):
   - `$env:LOCALAPPDATA\task-cli\tasks.db`
   - `$env:APPDATA\task-cli\config.yaml`

**Basic uninstall**:
```powershell
irm https://raw.githubusercontent.com/.../uninstall-windows.ps1 | iex
```

**Complete removal**:
```powershell
& ([scriptblock]::Create((irm ...uninstall-windows.ps1))) -Purge
```

## Artifact Naming Convention

All released artifacts follow this pattern:

```
task-cli_{VERSION}_{OS}_{ARCH}.{EXT}
```

**Example**:
- `task-cli_v1.2.3_linux_amd64.tar.gz` — Linux on Intel
- `task-cli_v1.2.3_darwin_arm64.tar.gz` — macOS on Apple Silicon
- `task-cli_v1.2.3_windows_amd64.zip` — Windows on Intel

**Checksum file**:
```
checksums.txt
```
Contains SHA256 hash for each artifact, one per line:
```
abc123... task-cli_v1.2.3_linux_amd64.tar.gz
def456... task-cli_v1.2.3_linux_arm64.tar.gz
...
```

## Checksum Verification

### Why Verify Checksums?

Ensures downloaded binary has not been corrupted or tampered with during transmission.

### Manual Verification

**Linux/macOS**:
```bash
# Download archive and checksums
curl -L -o task-cli.tar.gz https://github.com/.../releases/download/v1.2.3/task-cli_v1.2.3_linux_amd64.tar.gz
curl -L -o checksums.txt https://github.com/.../releases/download/v1.2.3/checksums.txt

# Verify
grep 'task-cli_v1.2.3_linux_amd64.tar.gz' checksums.txt | sha256sum -c -
# Output: task-cli_v1.2.3_linux_amd64.tar.gz: OK
```

**Windows PowerShell**:
```powershell
# Download
$url = "https://github.com/.../releases/download/v1.2.3/task-cli_v1.2.3_windows_amd64.zip"
$checksumsUrl = "https://github.com/.../releases/download/v1.2.3/checksums.txt"
Invoke-WebRequest -Uri $url -OutFile task-cli.zip
Invoke-WebRequest -Uri $checksumsUrl -OutFile checksums.txt

# Verify
$expected = (Select-String 'task-cli_v1.2.3_windows_amd64.zip' checksums.txt).Line.Split()[0]
$actual = (Get-FileHash -Path task-cli.zip -Algorithm SHA256).Hash
$expected -eq $actual  # Should output: True
```

### Automated Verification

Install scripts perform this verification automatically—no manual steps required.

## Release Process

### Creating a Release

1. **Tag the commit**:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

2. **GoReleaser builds and publishes**:
   - Triggered by GitHub Actions (if configured)
   - Or manually: `goreleaser release`
   - Builds 8 artifacts + checksums
   - Publishes to GitHub Releases
   - Generates CHANGELOG from commit messages

3. **Release available immediately**:
   - Install scripts auto-detect latest version
   - Users get v1.2.3 without version specification

### Version Format

Versions must follow semantic versioning: `vMAJOR.MINOR.PATCH`

Examples: v1.0.0, v1.2.3, v2.0.0-rc1

### Testing a Release Locally

```bash
# Build artifacts without publishing
goreleaser release --snapshot

# Creates dist/ directory with all 8 artifacts
ls dist/
```

## Troubleshooting Distribution Issues

### Installation Fails: "Checksum verification failed"

**Possible causes**:
- Network interruption during download
- GitHub rate limiting (get partial file)
- Disk space exhausted

**Solutions**:
```bash
# Retry installation
curl -fsSL https://raw.githubusercontent.com/.../install-linux.sh | bash

# If GitHub API rate-limited, specify version manually
VERSION=v1.2.3 bash install-linux.sh
```

### Installation Fails: "Command not found after install"

**Possible causes**:
- Installation directory not in PATH
- Shell doesn't see updated PATH (new terminal needed)

**Solutions**:
```bash
# Add to shell profile (~/.bashrc, ~/.zshrc, etc.)
export PATH="$PATH:/usr/local/bin"

# Or install to directory already in PATH
INSTALL_DIR=~/.local/bin install-linux.sh
```

### Installation Fails: "Permission denied"

**Linux/macOS**:
- Need sudo for /usr/local/bin (script handles automatically)
- Or use non-system directory: `INSTALL_DIR=~/.local/bin`

**Windows**:
- Run PowerShell as Administrator if installing system-wide
- Or use %LOCALAPPDATA% (user-level, recommended)

### Archive Extraction Fails: "tar: not found"

Unlikely on standard systems, but if occurring:
- Use manual binary download from GitHub Releases
- Extract with graphical archive manager (Windows/macOS)

### Plugin Directory Issues

If plugins not discovered after install:
```bash
# Ensure plugin directory exists
mkdir -p ~/.task-cli/bin

# Add to PATH if not already
export PATH="$PATH:$HOME/.task-cli/bin"
```

## Architecture Detection Details

### Linux Architecture Detection

```bash
uname -m
```

- `x86_64` → amd64 (Intel/AMD 64-bit)
- `aarch64` or `arm64` → arm64 (ARM 64-bit, newer Raspberry Pi, etc.)

### macOS Architecture Detection

```bash
uname -m
```

- `x86_64` → amd64 (Intel Mac)
- `arm64` → arm64 (Apple Silicon: M1, M2, M3, M4)

### Windows Architecture Detection

```powershell
[System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
```

- `X64` → amd64 (Intel/AMD 64-bit)
- `Arm64` → arm64 (Windows on ARM devices, Surface devices, etc.)

## Supported Platforms

| Platform | Architectures | Installation | Notes |
|----------|---|---|---|
| **Linux** | amd64, arm64 | Bash script | Requires curl, tar, sha256sum |
| **macOS** | amd64, arm64 | Bash script | Works on Intel and Apple Silicon |
| **Windows** | amd64, arm64 | PowerShell script | Requires PowerShell 5.1+ |

## See Also

- [Project Overview & PDR](./project-overview-pdr.md#deployment--distribution) - High-level deployment overview
- [Codebase Summary](./codebase-summary.md) - Architecture and modules
- [Code Standards](./code-standards.md) - Development guidelines
- [README.md](../README.md) - User installation instructions
