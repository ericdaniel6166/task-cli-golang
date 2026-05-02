#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Purge
)

$ErrorActionPreference = "Stop"

$BinaryName = "task-cli"
$InstallDir = "$env:LOCALAPPDATA\task-cli"
$DataDir = if ($env:TASK_CLI_DATA_DIR) { $env:TASK_CLI_DATA_DIR } else { "$env:USERPROFILE\.task-cli" }
$ConfigFile = "$env:USERPROFILE\.task-cli.yaml"

function Uninstall-TaskCli {
    # Find binary location
    $binaryPath = (Get-Command $BinaryName -ErrorAction SilentlyContinue).Source

    if (-not $binaryPath) {
        # Fallback to default install location
        $binaryPath = Join-Path $InstallDir "$BinaryName.exe"
    }

    if (Test-Path $binaryPath) {
        Write-Host "Removing $binaryPath..."
        Remove-Item -Path $binaryPath -Force

        # Remove install directory if empty
        $binaryDir = Split-Path $binaryPath -Parent
        if ((Test-Path $binaryDir) -and ((Get-ChildItem $binaryDir).Count -eq 0)) {
            Remove-Item -Path $binaryDir -Force
        }
    }
    else {
        Write-Host "$BinaryName not found (already removed?)"
    }

    # Remove from PATH
    if ($binaryPath) {
        $binaryDir = Split-Path $binaryPath -Parent
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -like "*$binaryDir*") {
            Write-Host "Removing from PATH..."
            $newPath = ($userPath -split ';' | Where-Object { $_ -ne $binaryDir }) -join ';'
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        }
    }

    Write-Host "Binary removed."

    if ($Purge) {
        Write-Host "Removing config and data..."
        if (Test-Path $DataDir) {
            Remove-Item -Path $DataDir -Recurse -Force
        }
        if (Test-Path $ConfigFile) {
            Remove-Item -Path $ConfigFile -Force
        }
        Write-Host "Config and data removed."
    }
    else {
        Write-Host "Config/data preserved. Use -Purge to remove."
    }

    Write-Host "Uninstall complete."
}

Uninstall-TaskCli
