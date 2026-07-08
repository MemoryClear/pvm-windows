# PVM PATH Setup Script
# Run this script in YOUR OWN PowerShell session (not via OpenClaw)
# This will add PVM to the BEGINNING of your PATH so it takes priority

$pvmHome = "$env:USERPROFILE\.pvm"
$currentBin = Join-Path $pvmHome "current"
$currentScripts = Join-Path $currentBin "Scripts"

# Check if PVM is installed
if (-not (Test-Path $currentBin)) {
    Write-Host "PVM not found at: $currentBin" -ForegroundColor Red
    Write-Host "Please run 'pvm use <version>' first." -ForegroundColor Yellow
    exit 1
}

# Get current user PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)

# Remove old PVM entries
$pvmPattern = [regex]::Escape($pvmHome) + "\\\\current"
$pathEntries = $userPath -split ";" | Where-Object { $_ -notmatch $pvmPattern }

# Prepend PVM paths (so they take priority over QClaw)
$newPath = "$currentBin;$currentScripts;" + ($pathEntries -join ";")

# Update user PATH
[Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)

# Also update current session PATH
$env:PATH = "$currentBin;$currentScripts;$env:PATH"

Write-Host "✅ PVM added to PATH (priority)" -ForegroundColor Green
Write-Host "  $currentBin" -ForegroundColor Gray
Write-Host "  $currentScripts" -ForegroundColor Gray
Write-Host ""
Write-Host "Now testing..." -ForegroundColor Cyan
$pythonPath = Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
$pipPath = Get-Command pip -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
Write-Host "  python: $(if ($pythonPath) { $pythonPath } else { 'not found' })" -ForegroundColor Gray
Write-Host "  pip: $(if ($pipPath) { $pipPath } else { 'not found' })" -ForegroundColor Gray
Write-Host ""
Write-Host "Please restart your PowerShell session to use the updated PATH." -ForegroundColor Yellow
