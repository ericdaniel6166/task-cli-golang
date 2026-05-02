#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Version,
    [string]$InstallDir = "$env:LOCALAPPDATA\task-cli"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Repo = "ericdaniel6166/task-cli-golang"
$BinaryName = "task-cli"

function Get-Architecture {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch ($arch) {
        "X64" { return "amd64" }
        "Arm64" { return "arm64" }
        default { throw "Unsupported architecture: $arch" }
    }
}

function Get-LatestVersion {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
    return $releases.tag_name
}

function Install-TaskCli {
    # Validate InstallDir parameter
    if ($InstallDir -match ';') {
        throw "InstallDir cannot contain semicolons"
    }

    $arch = Get-Architecture
    $ver = if ($Version) { $Version } else { Get-LatestVersion }
    $verClean = $ver -replace '^v', ''
    $archive = "${BinaryName}_${verClean}_windows_${arch}.zip"
    $url = "https://github.com/$Repo/releases/download/$ver/$archive"
    $checksumsUrl = "https://github.com/$Repo/releases/download/$ver/checksums.txt"

    Write-Host "Installing $BinaryName $ver for windows/$arch..."

    # Create temp directory
    $tmpDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.Guid]::NewGuid()))
    try {
        $archivePath = Join-Path $tmpDir $archive
        $checksumsPath = Join-Path $tmpDir "checksums.txt"

        # Download files
        Write-Host "Downloading..."
        Invoke-WebRequest -Uri $url -OutFile $archivePath
        Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath

        # Verify checksum
        Write-Host "Verifying checksum..."
        $expectedHash = (Get-Content $checksumsPath | Where-Object { $_ -match $archive } | ForEach-Object { ($_ -split '\s+')[0] })
        $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLower()

        if ($expectedHash -ne $actualHash) {
            throw "Checksum verification failed!`nExpected: $expectedHash`nActual: $actualHash"
        }

        # Extract
        Write-Host "Extracting..."
        Expand-Archive -Path $archivePath -DestinationPath $tmpDir -Force

        # Create install directory
        if (-not (Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }

        # Copy binary
        $binaryPath = Join-Path $tmpDir "$BinaryName.exe"
        Copy-Item -Path $binaryPath -Destination $InstallDir -Force

        Write-Host "Installed to $InstallDir\$BinaryName.exe"

        # Add to PATH if not already
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$InstallDir*") {
            Write-Host "Adding to PATH..."
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallDir", "User")
            $env:Path = "$env:Path;$InstallDir"
            Write-Host "Added $InstallDir to User PATH"
            Write-Host "Restart your terminal for PATH changes to take effect."
        }

        Write-Host "`nInstallation complete! Run 'task-cli --help' to get started."
    }
    finally {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Install-TaskCli
