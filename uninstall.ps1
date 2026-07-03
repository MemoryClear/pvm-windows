<#
.SYNOPSIS
    PVM Uninstaller for Windows
.DESCRIPTION
    Remove PVM and all its data from the system.
#>

param(
    [switch]$Force
)

Set-StrictMode -Version Latest

$PVM_HOME = if ($env:PVM_HOME) { $env:PVM_HOME } else { Join-Path $env:USERPROFILE ".pvm" }

Write-Host ""
Write-Host "  PVM Uninstaller" -ForegroundColor White
Write-Host ""

if (-not $Force) {
    Write-Host "  This will remove:" -ForegroundColor Yellow
    Write-Host "    - PVM scripts and configuration from: $PVM_HOME" -ForegroundColor White
    Write-Host "    - All installed Python versions" -ForegroundColor White
    Write-Host "    - PVM_HOME and PATH environment variable entries" -ForegroundColor White
    Write-Host ""
    $confirm = Read-Host "  Are you sure? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "  Cancelled." -ForegroundColor Gray
        exit 0
    }
}

# Remove from PATH (bin, current, current\Scripts)
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$pvmEntries = @(
    (Join-Path $PVM_HOME "bin"),
    (Join-Path $PVM_HOME "current"),
    (Join-Path $PVM_HOME "current\Scripts")
)
$newPath = ($userPath -split ";" | Where-Object {
    $_ -ne "" -and $_ -notin $pvmEntries
}) -join ";"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
Write-Host "  [OK] Removed PVM entries from PATH" -ForegroundColor Green

# Remove PVM_HOME env var
[Environment]::SetEnvironmentVariable("PVM_HOME", $null, "User")
Write-Host "  [OK] Removed PVM_HOME environment variable" -ForegroundColor Green

# Remove PVM directory
if (Test-Path $PVM_HOME) {
    Remove-Item $PVM_HOME -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $PVM_HOME)) {
        Write-Host "  [OK] Removed: $PVM_HOME" -ForegroundColor Green
    } else {
        Write-Host "  [!!] Some files could not be removed. Try manually deleting: $PVM_HOME" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [--] $PVM_HOME not found (already removed?)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  PVM has been uninstalled." -ForegroundColor Green
Write-Host "  Restart your terminal for changes to take effect." -ForegroundColor Yellow
Write-Host ""
