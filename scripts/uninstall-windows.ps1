#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Purge
)

$ErrorActionPreference = "Stop"

$BinaryName = "task-cli"
$InstallDir = "$env:LOCALAPPDATA\task-cli"
$ConfigDir = "$env:APPDATA\task-cli"

function Uninstall-TaskCli {
    # Remove binary
    $binaryPath = Join-Path $InstallDir "$BinaryName.exe"

    if (Test-Path $binaryPath) {
        Write-Host "Removing $binaryPath..."
        Remove-Item -Path $binaryPath -Force
    }

    # Remove install directory if empty
    if ((Test-Path $InstallDir) -and ((Get-ChildItem $InstallDir).Count -eq 0)) {
        Remove-Item -Path $InstallDir -Force
    }

    # Remove from PATH
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -like "*$InstallDir*") {
        Write-Host "Removing from PATH..."
        $newPath = ($userPath -split ';' | Where-Object { $_ -ne $InstallDir }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }

    Write-Host "Binary removed."

    if ($Purge) {
        Write-Host "Removing config and data..."
        if (Test-Path $ConfigDir) {
            Remove-Item -Path $ConfigDir -Recurse -Force
        }
        if (Test-Path $InstallDir) {
            Remove-Item -Path $InstallDir -Recurse -Force
        }
        Write-Host "Config and data removed."
    }
    else {
        Write-Host "Config/data preserved. Use -Purge to remove."
    }

    Write-Host "Uninstall complete."
}

Uninstall-TaskCli
