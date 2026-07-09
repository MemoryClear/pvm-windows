@echo off
:: PVM launcher - reads PVM_HOME from environment, falls back to default
if not defined PVM_HOME set "PVM_HOME=%USERPROFILE%\.pvm"
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%PVM_HOME%\bin\pvm.ps1" %*
    goto :done
)
where powershell.exe >nul 2>&1
if %errorlevel%==0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PVM_HOME%\bin\pvm.ps1" %*
    goto :done
)
echo ERROR: PowerShell not found.
exit /b 1
:done
:: Refresh PATH from registry (delims= preserves full value including semicolons)
for /f "tokens=2* delims=" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul ^| findstr REG_') do (
    set "PATH=%%B"
)
