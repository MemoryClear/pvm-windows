<#
.SYNOPSIS
    PVM Installer for Windows
.DESCRIPTION
    Install PVM (Python Version Manager) and configure the system.
    Supports custom installation directory.
.NOTES
    Requirements: This script must be in the same directory as pvm.ps1 and uninstall.ps1.
    Usage:
        powershell -ExecutionPolicy Bypass -File install.ps1
        powershell -ExecutionPolicy Bypass -File install.ps1 -InstallDir D:\pvm
        powershell -ExecutionPolicy Bypass -File install.ps1 -InstallDir "C:\My Tools\pvm"
#>

param(
    [string]$InstallDir,
    [switch]$Quiet,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PVM_VERSION = '1.1.1'
$DEFAULT_INSTALL = Join-Path $env:USERPROFILE '.pvm'
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Banner
if (-not $Quiet) {
    Write-Host ''
    Write-Host '  ==============================================' -ForegroundColor Cyan
    Write-Host '  |                                            |' -ForegroundColor Cyan
    Write-Host "  |   PVM - Python Version Manager v$PVM_VERSION    |" -ForegroundColor Cyan
    Write-Host '  |   For Windows                              |' -ForegroundColor Cyan
    Write-Host '  |                                            |' -ForegroundColor Cyan
    Write-Host '  ==============================================' -ForegroundColor Cyan
    Write-Host ''
}

# Determine Install Directory
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = $DEFAULT_INSTALL
}

# Expand environment variables in InstallDir
$InstallDir = [Environment]::ExpandEnvironmentVariables($InstallDir)

# Check if PVM is already installed elsewhere
$existingPvmHome = [Environment]::GetEnvironmentVariable('PVM_HOME', 'User')
if (-not $existingPvmHome) {
    $defaultSettingsPath = Join-Path $DEFAULT_INSTALL 'settings.json'
    if (Test-Path $defaultSettingsPath) {
        try {
            $settings = Get-Content $defaultSettingsPath -Raw | ConvertFrom-Json
            if ($settings.root) { $existingPvmHome = $settings.root }
        } catch { }
    }
}

if ($existingPvmHome -and (Test-Path $existingPvmHome)) {
    if ($existingPvmHome -ne $InstallDir) {
        Write-Host ''
        Write-Host '  WARNING: PVM is already installed at:' -ForegroundColor Yellow
        Write-Host "    $existingPvmHome" -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Options:' -ForegroundColor Cyan
        Write-Host '    1. Continue: Install PVM to new location (two installations will exist)' -ForegroundColor White
        Write-Host '    2. Cancel: Press Ctrl+C to cancel' -ForegroundColor White
        Write-Host ''
        if (-not $Force) {
            $response = Read-Host '  Continue? (y/N)'
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host '  Installation cancelled.' -ForegroundColor Yellow
                exit 0
            }
        }
    }
}

$binDir = Join-Path $InstallDir 'bin'
$versionsDir = Join-Path $InstallDir 'versions'

Write-Host "  Installing PVM to: $InstallDir" -ForegroundColor White
Write-Host ''

# Create all directories
foreach ($dir in @($InstallDir, $binDir, $versionsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  [OK] Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  [--] Exists:  $dir" -ForegroundColor Gray
    }
}

# Copy Script Files
$filesToCopy = @{
    'pvm.ps1' = Join-Path $binDir 'pvm.ps1'
    'uninstall.ps1' = Join-Path $binDir 'uninstall.ps1'
}

foreach ($src in $filesToCopy.Keys) {
    $srcPath = Join-Path $SCRIPT_DIR $src
    $dstPath = $filesToCopy[$src]
    if (Test-Path $srcPath) {
        Copy-Item $srcPath $dstPath -Force
        Write-Host "  [OK] Installed: $src" -ForegroundColor Green
    } else {
        Write-Host "  [!!] Not found: $src (skipped)" -ForegroundColor Yellow
    }
}

# Create launcher batch file
# Note: We avoid complex for/f syntax that has backtick issues in PowerShell here-strings
$launcherContent = "@echo off`r`n"
$launcherContent += ":: PVM launcher - auto-detects PowerShell`r`n"
$launcherContent += "set `"PVM_HOME=$InstallDir`"`r`n"
$launcherContent += "set `"PVM_BIN=$binDir`"`r`n"
$launcherContent += "where pwsh.exe >nul 2>&1`r`n"
$launcherContent += "if %errorlevel%==0 (`r`n"
$launcherContent += "    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"%PVM_BIN%\pvm.ps1`" %*`r`n"
$launcherContent += "    goto :done`r`n"
$launcherContent += ")`r`n"
$launcherContent += "where powershell.exe >nul 2>&1`r`n"
$launcherContent += "if %errorlevel%==0 (`r`n"
$launcherContent += "    powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%PVM_BIN%\pvm.ps1`" %*`r`n"
$launcherContent += "    goto :done`r`n"
$launcherContent += ")`r`n"
$launcherContent += "echo ERROR: PowerShell not found.`r`n"
$launcherContent += "exit /b 1`r`n"
$launcherContent += ":done`r`n"
$launcherContent += ":: Refresh PATH from registry (delims= preserves full value including semicolons)`r`n"
$launcherContent += "for /f `"tokens=2* delims=`" %%A in ('reg query `"HKCU\Environment`" /v PATH 2^>nul ^| findstr REG_') do (`r`n"
$launcherContent += "    set `"PATH=%%B`"`r`n"
$launcherContent += ")"

$launcherPath = Join-Path $binDir 'pvm.bat'
$launcherContent | Set-Content $launcherPath -Encoding ASCII
Write-Host '  [OK] Created launcher: pvm.bat' -ForegroundColor Green

# Add to PATH
Write-Host ''
Write-Host '  Configuring PATH ...' -ForegroundColor Cyan

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -split ';' -contains $binDir) {
    Write-Host "  [--] PATH already contains: $binDir" -ForegroundColor Gray
} else {
    $newPath = "$binDir;$userPath"
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "  [OK] Added to user PATH: $binDir" -ForegroundColor Green
}

# Initialize settings.json
$settingsPath = Join-Path $InstallDir 'settings.json'
if (-not (Test-Path $settingsPath)) {
    $settings = [PSCustomObject]@{
        root = $InstallDir
        python_mirror = 'https://www.python.org/ftp/python/'
        pip_mirror = 'https://pypi.org/simple/'
    }
    $settings | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
    Write-Host '  [OK] Created settings.json' -ForegroundColor Green
} else {
    Write-Host '  [--] settings.json already exists' -ForegroundColor Gray
}

# Set PVM_HOME
[Environment]::SetEnvironmentVariable('PVM_HOME', $InstallDir, 'User')
Write-Host "  [OK] Set PVM_HOME=$InstallDir" -ForegroundColor Green

# Summary
Write-Host ''
Write-Host '  ==============================================' -ForegroundColor Green
Write-Host '  |        PVM installed successfully!         |' -ForegroundColor Green
Write-Host '  ==============================================' -ForegroundColor Green
Write-Host ''
Write-Host "  Installation:  $InstallDir" -ForegroundColor White
Write-Host "  Binary:        $binDir" -ForegroundColor White
Write-Host "  Versions:      $versionsDir" -ForegroundColor White
Write-Host ''
Write-Host '  Getting started:' -ForegroundColor Cyan
Write-Host '    1. Restart your terminal (or open a new one)' -ForegroundColor White
Write-Host '    2. Run: pvm help' -ForegroundColor White
Write-Host '    3. Install Python: pvm install latest' -ForegroundColor White
Write-Host ''
Write-Host '  China users - set mirrors first:' -ForegroundColor Yellow
Write-Host '    pvm python_mirror https://registry.npmmirror.com/-/binary/python/' -ForegroundColor Gray
Write-Host '    pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/' -ForegroundColor Gray
Write-Host ''
Write-Host '  To uninstall PVM:' -ForegroundColor Gray
Write-Host '    1. Remove installed versions: pvm uninstall ^<version^>' -ForegroundColor Gray
Write-Host "    2. Delete: $InstallDir" -ForegroundColor Gray
Write-Host "    3. Remove $binDir from PATH" -ForegroundColor Gray
Write-Host '    4. Remove PVM_HOME env var' -ForegroundColor Gray
Write-Host ''


# Migration hint (if PVM was already installed)
if ($existingPvmHome -and $existingPvmHome -ne $InstallDir) {
    Write-Host ''
    Write-Host '  To migrate existing Python versions to the new location:' -ForegroundColor Cyan
    Write-Host '    1. Restart your terminal (so pvm command is available)' -ForegroundColor White
    Write-Host "    2. Run: pvm root $existingPvmHome"
    Write-Host ''
    Write-Host '    This will automatically migrate all versions and settings.' -ForegroundColor Gray
    Write-Host ''
}

