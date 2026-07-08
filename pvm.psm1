# PVM PowerShell Module
# This module provides PVM functionality directly in your PowerShell session
# Usage: 
#   1. Copy this file to your PowerShell profile directory
#   2. Add to your profile: Import-Module "D:\pvm\bin\pvm.psm1"
#   3. Restart PowerShell or run: . $PROFILE
#   4. Use: pvm use 3.12.9

$scriptPath = "D:\pvm\bin\pvm.ps1"

function Invoke-Pvm {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Arguments
    )
    
    # Run PVM script with arguments
    & $scriptPath @Arguments
}

# Create pvm alias
Set-Alias -Name pvm -Value Invoke-Pvm

# Export the function and alias
Export-ModuleMember -Function Invoke-Pvm -Alias pvm
