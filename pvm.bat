@echo off
:: PVM - Python Version Manager for Windows
:: Wrapper batch file for cmd.exe
:: Delegates to pvm.ps1 PowerShell script

:: Detect PVM_HOME
if "%PVM_HOME%"=="" (
    set "PVM_HOME=%USERPROFILE%\.pvm"
)

:: Find the pvm.ps1 script location
set "PVM_SCRIPT=%~dp0pvm.ps1"

:: If not found in same directory, try PVM_HOME
if not exist "%PVM_SCRIPT%" (
    set "PVM_SCRIPT=%PVM_HOME%\bin\pvm.ps1"
)

:: Check PowerShell is available
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%PVM_SCRIPT%" %*
    goto :done
)

where powershell.exe >nul 2>&1
if %errorlevel%==0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PVM_SCRIPT%" %*
    goto :done
)

echo ERROR: PowerShell not found. PVM requires PowerShell to run.
echo Please install PowerShell 5.1+ or PowerShell 7+.
exit /b 1

:done
:: Refresh PATH from registry so subsequent commands in the same session work
for /f "tokens=2* delims=" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul ^| findstr REG_') do (
    set "PATH=%%B"
)
