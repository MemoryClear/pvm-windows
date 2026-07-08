# PVM Initialization Script
# Add this to your PowerShell profile to enable PVM in every session
# 
# Usage:
#   1. Edit your PowerShell profile: notepad $PROFILE
#   2. Add this line: . "D:\pvm\bin\pvm-init.ps1"
#   3. Restart PowerShell or run: . $PROFILE
#   4. Use: pvm use 3.12.9

$script:PVMBinDir = "D:\pvm\bin"
$script:PVMHome = $env:PVM_HOME
if ([string]::IsNullOrWhiteSpace($script:PVMHome)) { $script:PVMHome = "$env:USERPROFILE\.pvm" }
$script:PVMHome = $script:PVMHome -replace '/','\'

function pvm {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Arguments
    )
    
    $pvmScript = Join-Path $script:PVMBinDir "pvm.ps1"
    
    if ($Arguments.Count -eq 0) {
        & $pvmScript
        return
    }
    
    $command = $Arguments[0]
    $remainingArgs = @()
    if ($Arguments.Count -gt 1) { $remainingArgs = $Arguments[1..($Arguments.Count-1)] }
    
    switch ($command) {
        "use" {
            if ($remainingArgs.Count -gt 0) {
                $version = $remainingArgs[0]
                & $pvmScript use $version
                
                # Update current session PATH
                $currentLink = Join-Path $script:PVMHome "current"
                if (Test-Path $currentLink) {
                    $currentBin = $currentLink
                    $currentScripts = Join-Path $currentLink "Scripts"
                    
                    # Prepend to current session PATH
                    $currentPath = $env:PATH -split ";" | Where-Object { $_ -notmatch [regex]::Escape($script:PVMHome) + "\\\\current" }
                    $env:PATH = "$currentBin;$currentScripts;" + ($currentPath -join ";")
                    
                    Write-Host "  Current session PATH updated." -ForegroundColor Green
                }
            } else {
                & $pvmScript use
            }
        }
        default {
            & $pvmScript @Arguments
        }
    }
}

Write-Host "PVM loaded. Use 'pvm use <version>' to switch Python versions." -ForegroundColor Cyan
Write-Host "  This will also update the current session's PATH." -ForegroundColor Gray
