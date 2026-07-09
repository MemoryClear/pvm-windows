<#
.SYNOPSIS
    PVM - Python Version Manager for Windows (v1.1.1)
.DESCRIPTION
    Manage multiple Python installations on Windows.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [Parameter(ValueFromRemainingArguments = $true)]$RemainingArgs
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:PVM_VERSION = "1.1.1"
$script:DEFAULT_PVM_HOME = Join-Path $env:USERPROFILE ".pvm"
$script:DEFAULT_PYTHON_MIRROR = "https://www.python.org/ftp/python/"
$script:DEFAULT_PIP_MIRROR = "https://pypi.org/simple/"
$script:NPM_MIRROR_PYTHON = "https://registry.npmmirror.com/-/binary/python/"
$script:NPM_MIRROR_PIP = "https://pypi.tuna.tsinghua.edu.cn/simple/"

# Initialize PVM_HOME at script load time
$script:PVM_HOME = $env:PVM_HOME
if ([string]::IsNullOrWhiteSpace($script:PVM_HOME)) {
    $defaultSettingsPath = Join-Path $script:DEFAULT_PVM_HOME "settings.json"
    if (Test-Path $defaultSettingsPath) {
        try {
            $settings = Get-Content $defaultSettingsPath -Raw | ConvertFrom-Json
            if ($settings.root) { $script:PVM_HOME = $settings.root }
        } catch { }
    }
}
if ([string]::IsNullOrWhiteSpace($script:PVM_HOME)) {
    $script:PVM_HOME = $script:DEFAULT_PVM_HOME
}

function Get-PvmHome {
    return $script:PVM_HOME
}

function Get-SettingsPath {
    return Join-Path $script:PVM_HOME "settings.json"
}

function Get-Settings {
    $path = Get-SettingsPath
    $defaultSettings = [PSCustomObject]@{
        python_mirror = $null
        pip_mirror = $null
        get_pip_url = $null
        root = $null
    }
    if (Test-Path $path) {
        try { 
            $content = Get-Content $path -Raw
            if ($content) { 
                $settings = $content | ConvertFrom-Json
                # Merge with defaults
                if ($settings.python_mirror) { $defaultSettings.python_mirror = $settings.python_mirror }
                if ($settings.pip_mirror) { $defaultSettings.pip_mirror = $settings.pip_mirror }
                if ($settings.get_pip_url) { $defaultSettings.get_pip_url = $settings.get_pip_url }
                if ($settings.root) { $defaultSettings.root = $settings.root }
                return $defaultSettings
            }
        }
        catch { }
    }
    return $defaultSettings
}

function Save-Settings {
    param($Settings)
    $pvmHomeDir = Get-PvmHome
    if (-not (Test-Path $pvmHomeDir)) { New-Item -ItemType Directory -Path $pvmHomeDir -Force | Out-Null }
    $Settings | ConvertTo-Json -Depth 5 | Set-Content (Get-SettingsPath) -Encoding UTF8
}

function Get-PythonMirror {
    $s = Get-Settings
    if ($s.python_mirror) { return $s.python_mirror }
    return $script:DEFAULT_PYTHON_MIRROR
}

function Get-PipMirror {
    $s = Get-Settings
    if ($s.pip_mirror) { return $s.pip_mirror }
    return $script:DEFAULT_PIP_MIRROR
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-UrlExists {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        return $true
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 404) { return $false }
        return $true
    }
    catch { return $true }
}

function Get-InstalledVersions {
    $dir = Join-Path (Get-PvmHome) "versions"
    if (-not (Test-Path $dir)) { return @() }
    $versions = [System.Collections.Generic.List[string]]::new()
    Get-ChildItem -Path $dir -Directory | ForEach-Object {
        if (Test-Path (Join-Path $_.FullName "python.exe")) { $versions.Add($_.Name) }
    }
    if ($versions.Count -eq 0) { return @() }
    return $versions | Sort-Object { try { [version]($_ -replace '-.*','') } catch { [version]"0.0.0" } } -Descending
}

function Get-AvailableVersions {
    $mirror = Get-PythonMirror
    $cacheFile = Join-Path (Get-PvmHome) "available_versions.cache"
    $cacheExpiry = (Get-Date).AddHours(-4)
    if ((Test-Path $cacheFile) -and (Get-Item $cacheFile).LastWriteTime -gt $cacheExpiry) {
        return Get-Content $cacheFile | Where-Object { $_ -match '^\d+\.\d+\.\d+' }
    }
    try {
        Write-Host "Fetching available versions..." -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $mirror -UseBasicParsing -TimeoutSec 30
        
        # Try JSON API format (registry.npmmirror.com)
        if ($response.Content -match '^\s*\[') {
            $json = $response.Content | ConvertFrom-Json
            $all = $json | Where-Object { $_.type -eq 'dir' -and $_.name -match '^(\d+\.\d+\.\d+)/$' } | ForEach-Object { $_.name.TrimEnd('/') }
        } else {
            # Fallback to HTML directory listing (python.org)
            $all = [regex]::Matches($response.Content, '>(\d+\.\d+\.\d+)/') | ForEach-Object { $_.Groups[1].Value }
        }
        
        $stable = $all | Where-Object { $_ -match '^3\.\d+\.\d+$' } | Sort-Object { [version]$_ } -Descending | Select-Object -Unique
        $stable | Set-Content $cacheFile -Encoding UTF8
        return $stable
    }
    catch {
        if (Test-Path $cacheFile) { return Get-Content $cacheFile }
        throw "Failed to fetch versions: $_"
    }
}

function Get-ArchString {
    # Returns architecture string for embeddable zip download
    # 64-bit Windows: amd64
    # 32-bit Windows: win32
    if ([Environment]::Is64BitOperatingSystem) {
        return "amd64"
    } else {
        return "win32"
    }
}

function Get-DownloadUrl {
    param([string]$Version, [string]$Arch)
    if ([string]::IsNullOrWhiteSpace($Arch)) { $Arch = Get-ArchString }
    return "$(Get-PythonMirror)$Version/python-$Version-embed-$Arch.zip"
}

function Download-File {
    param([string]$Url, [string]$OutFile, [string]$Description = "Downloading")
    Write-Host "$Description : $Url" -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "PVM/1.0")
        $wc.DownloadFile($Url, $OutFile)
        return $true
    }
    catch {
        if ($_.Exception.InnerException -is [System.Net.WebException]) {
            $webEx = $_.Exception.InnerException
            if ($webEx.Response -and [int]$webEx.Response.StatusCode -eq 404) {
                Write-ColorOutput "Error: Python version not found (404)" "Red"
                Write-Host "This version may not have Windows packages released yet." -ForegroundColor Yellow
                return $false
            }
        }
        Write-ColorOutput "Download failed: $_" "Red"
        return $false
    }
}

function Install-Pip {
    param([string]$VersionDir)
    $pythonExe = Join-Path $VersionDir "python.exe"
    if (-not (Test-Path $pythonExe)) { return $false }
    
    # Fix python._pth: uncomment 'import site' and ensure no BOM
    $pthFile = Get-ChildItem -Path $VersionDir -Filter "python*._pth" | Select-Object -First 1
    if ($pthFile) {
        $raw = Get-Content $pthFile.FullName -Raw -Encoding UTF8
        $lines = ($raw -split "`r?`n") | Where-Object { $_ -ne "" }
        $fixed = @()
        foreach ($line in $lines) {
            if ($line -match "^#import site$") { $fixed += "import site" }
            else { $fixed += $line }
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllText($pthFile.FullName, ($fixed -join "`n"), $utf8NoBom)
    }
    
    # Download get-pip.py
    $getPipBytes = $null
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "PVM/1.0")
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $getPipBytes = $wc.DownloadData("https://bootstrap.pypa.io/get-pip.py")
    } catch {
        Write-ColorOutput "  Failed to download get-pip.py: $_" "Red"
        return $false
    }
    
    # Run via stdin pipe
    $savedPythonHome = $env:PYTHONHOME
    $savedPythonPath = $env:PYTHONPATH
    $env:PYTHONHOME = $null
    $env:PYTHONPATH = $null
    $success = $false
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $pythonExe
        $psi.Arguments = "- --no-warn-script-location"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        Start-Sleep -Milliseconds 500
        $proc.StandardInput.BaseStream.Write($getPipBytes, 0, $getPipBytes.Length)
        $proc.StandardInput.Close()
        $proc.WaitForExit()
        $success = ($proc.ExitCode -eq 0)
    } catch {
        Write-ColorOutput "  get-pip.py failed: $_" "Yellow"
    } finally {
        $env:PYTHONHOME = $savedPythonHome
        $env:PYTHONPATH = $savedPythonPath
    }
    return $success
}

function Resolve-PythonVersion {
    param([string]$Version)
    if ($Version -eq "latest") {
        $versions = Get-AvailableVersions
        if ($versions.Count -eq 0) { throw "No versions found." }
        return $versions[0]
    }
    if ($Version -match '^\d+\.\d+$') {
        $matching = Get-AvailableVersions | Where-Object { $_ -like "$Version.*" -and $_ -notmatch '[a-zA-Z]' } | Sort-Object { [version]($_ -replace '-.*','') } -Descending
        if ($matching.Count -gt 0) { return $matching[0] }
        throw "No version found matching '$Version'."
    }
    return $Version
}

function Get-VersionsDir { return Join-Path (Get-PvmHome) "versions" }
function Get-CurrentLink { return Join-Path (Get-PvmHome) "current" }
function Get-CurrentVersion {
    $link = Get-CurrentLink
    if (-not (Test-Path $link)) { return $null }
    return Split-Path (Get-Item $link).Target -Leaf
}

# ─── Command Implementations ─────────────────────────────────────────────────

function Invoke-PvmInstall {
    param([string]$Version, [string]$Arch)
    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-ColorOutput "Usage: pvm install <version> [--arch x64|x86]" "Yellow"
        return
    }
    # Parse --arch from remaining args or validate
    $requestedArch = ""
    if (-not [string]::IsNullOrWhiteSpace($Arch)) {
        $a = $Arch.ToLower()
        if ($a -eq "x64" -or $a -eq "amd64") { $requestedArch = "amd64" }
        elseif ($a -eq "x86" -or $a -eq "win32" -or $a -eq "32") { $requestedArch = "win32" }
        else { Write-ColorOutput "Invalid arch: $Arch. Use x64 or x86." "Red"; return }
    }
    $isAlias = ($Version -eq "latest" -or $Version -match '^\d+\.\d+$')
    try { $resolvedVersion = Resolve-PythonVersion $Version }
    catch { Write-ColorOutput "Error: $_" "Red"; return }
    
    $versionsToTry = @()
    if ($isAlias) {
        $allVersions = @(Get-AvailableVersions)
        $startIndex = $allVersions.IndexOf($resolvedVersion)
        if ($startIndex -ge 0) {
            $versionsToTry = $allVersions[$startIndex..([Math]::Min($startIndex + 5, $allVersions.Count - 1))]
        } else { $versionsToTry = @($resolvedVersion) }
    } else { $versionsToTry = @($resolvedVersion) }
    
    foreach ($versionToTry in $versionsToTry) {
        $versionDir = Join-Path (Get-VersionsDir) $versionToTry
        if (Test-Path (Join-Path $versionDir "python.exe")) {
            Write-ColorOutput "Python $versionToTry is already installed." "Yellow"
            return
        }
        
        $arch = if (-not [string]::IsNullOrWhiteSpace($requestedArch)) { $requestedArch } else { Get-ArchString }
        $downloadUrl = Get-DownloadUrl $versionToTry $arch
        Write-Host "Checking availability of Python $versionToTry ($arch) ..." -ForegroundColor Gray
        if (-not (Test-UrlExists $downloadUrl)) {
            Write-ColorOutput "Python $versionToTry does not have Windows packages released yet." "Yellow"
            if ($isAlias -and $versionToTry -ne $versionsToTry[-1]) {
                Write-Host "Trying next version..." -ForegroundColor Gray
                continue
            } else {
                Write-Host ""
                Write-Host "Available versions with Windows packages:" -ForegroundColor Cyan
                $count = 0
                foreach ($v in @(Get-AvailableVersions)) {
                    if ((Test-UrlExists (Get-DownloadUrl $v)) -and $count -lt 5) {
                        Write-Host "  pvm install $v" -ForegroundColor Green
                        $count++
                    }
                }
                Write-Host ""
                Write-Host "Hint: pvm python_mirror $script:NPM_MIRROR_PYTHON" -ForegroundColor Gray
                return
            }
        }
        
        $zipFile = Join-Path $env:TEMP "python-$versionToTry-embed-$arch.zip"
        Write-Host ""
        Write-Host "Installing Python $versionToTry ($arch) ..." -ForegroundColor White
        if (Download-File -Url $downloadUrl -OutFile $zipFile) {
            Write-Host "Extracting to: $versionDir" -ForegroundColor Cyan
            if (Test-Path $versionDir) { Remove-Item $versionDir -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
            try {
                Expand-Archive -Path $zipFile -DestinationPath $versionDir -Force
            } catch {
                Write-ColorOutput "  Extract failed: $_" "Red"
                Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
                return
            }
            Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
            
            $pythonExe = Join-Path $versionDir "python.exe"
            if (-not (Test-Path $pythonExe)) {
                Write-ColorOutput "Installation failed: python.exe not found" "Red"
                return
            }
            Write-ColorOutput "  Extracted: $(& $pythonExe --version 2>&1)" "Green"
            
            if (Install-Pip $versionDir) {
                Write-ColorOutput "  pip installed" "Green"
            } else {
                Write-ColorOutput "  Warning: pip install failed" "Yellow"
            }
            if (-not (Get-CurrentVersion)) { Invoke-PvmUse $versionToTry }
            Write-ColorOutput "Python $versionToTry installed successfully!" "Green"
            return
        } else {
            if ($isAlias -and $versionToTry -ne $versionsToTry[-1]) { continue }
            return
        }
    }
}

function Invoke-PvmUse {
    param([string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { Write-ColorOutput "Usage: pvm use <version>" "Yellow"; return }
    
    $versionsDir = Get-VersionsDir
    if ($Version -eq "newest") {
        $installed = Get-InstalledVersions
        if ($installed.Count -eq 0) { Write-ColorOutput "No versions installed." "Yellow"; return }
        $Version = $installed[0]
    }
    
    $versionDir = Join-Path $versionsDir $Version
    if (-not (Test-Path (Join-Path $versionDir "python.exe"))) {
        Write-ColorOutput "Python $Version is not installed." "Yellow"
        return
    }
    
    $currentLink = Get-CurrentLink
    if (Test-Path $currentLink) {
        cmd /c rmdir $currentLink 2>$null
    }
    New-Item -ItemType Junction -Path $currentLink -Target $versionDir | Out-Null
    
    # Add current version to PATH (prepend for priority)
    $currentBin = $currentLink
    $currentScripts = Join-Path $currentLink "Scripts"
    
    # Update user PATH (for future sessions)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    $pvmHome = Get-PvmHome
    $currentPattern = [regex]::Escape($pvmHome) + "\\current"
    
    # Remove old PVM current entries from PATH
    $pathEntries = $userPath -split ";" | Where-Object { $_ -notmatch $currentPattern }
    
    # Prepend new entries (so PVM takes priority)
    $newPath = "$currentBin;$currentScripts;" + ($pathEntries -join ";")
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
    
    # Also update current session PATH (prepend)
    $currentPath = $env:PATH -split ";" | Where-Object { $_ -notmatch $currentPattern }
    $env:PATH = "$currentBin;$currentScripts;" + ($currentPath -join ";")
    
    Write-Host "  Added to PATH (priority): $currentBin" -ForegroundColor Gray
    Write-Host "  Added to PATH (priority): $currentScripts" -ForegroundColor Gray
    Write-ColorOutput "Switched to Python $Version" "Green"
    Write-Host "  pip and python commands now use PVM version." -ForegroundColor Cyan
}

function Invoke-PvmList {
    param([switch]$Available, [switch]$Check)
    if ($Available) {
        Write-Host ""
        Write-Host "Available Python versions:" -ForegroundColor White
        $versions = @(Get-AvailableVersions)
        $installed = @(Get-InstalledVersions)
        $current = Get-CurrentVersion
        $count = 0
        foreach ($v in $versions) {
            if ($count -ge 30) { break }
            
            # Check if this version has Windows packages
            $hasPackage = $true
            if ($Check) {
                $downloadUrl = Get-DownloadUrl $v
                $hasPackage = Test-UrlExists $downloadUrl
            }
            
            $status = ""
            if ($v -eq $current) { $status = " (active, installed)" }
            elseif ($installed -contains $v) { $status = " (installed)" }
            
            if ($Check) {
                if ($hasPackage) {
                    if ($v -eq $current) { Write-ColorOutput "  * $v$status" "Green" }
                    elseif ($installed -contains $v) { Write-ColorOutput "    $v$status" "Cyan" }
                    else { Write-Host "    $v" }
                } else {
                    Write-Host "    $v" -ForegroundColor DarkGray
                    Write-Host " (no Windows package)" -ForegroundColor DarkRed -NoNewline
                    Write-Host ""
                }
            } else {
                if ($v -eq $current) { Write-ColorOutput "  * $v$status" "Green" }
                elseif ($installed -contains $v) { Write-ColorOutput "    $v$status" "Cyan" }
                else { Write-Host "    $v" }
            }
            $count++
        }
        if ($Check) {
            Write-Host ""
            Write-Host "Note: Versions displayed in dark gray have no Windows packages." -ForegroundColor Gray
        }
    } else {
        $installed = @(Get-InstalledVersions)
        if ($installed.Count -eq 0) {
            Write-Host "No Python versions installed." -ForegroundColor Yellow
        } else {
            Write-Host "Installed versions:" -ForegroundColor White
            $current = Get-CurrentVersion
            foreach ($v in $installed) {
                if ($v -eq $current) { Write-ColorOutput "  * $v (active)" "Green" }
                else { Write-Host "    $v" }
            }
        }
    }
}

function Invoke-PvmCurrent {
    $current = Get-CurrentVersion
    if ($current) {
        $pythonExe = Join-Path (Get-CurrentLink) "python.exe"
        $version = & $pythonExe --version 2>&1
        Write-ColorOutput "Currently using: $version" "Green"
    } else {
        Write-Host "No active Python version." -ForegroundColor Yellow
    }
}

function Invoke-PvmUninstall {
    param([string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { Write-ColorOutput "Usage: pvm uninstall <version>" "Yellow"; return }
    $current = Get-CurrentVersion
    if ($Version -eq $current) { Write-ColorOutput "Cannot uninstall active version." "Red"; return }
    $versionDir = Join-Path (Get-VersionsDir) $Version
    if (-not (Test-Path $versionDir)) { Write-ColorOutput "Python $Version is not installed." "Yellow"; return }
    Remove-Item $versionDir -Recurse -Force
    Write-ColorOutput "Python $Version uninstalled." "Green"
}

function Invoke-PvmRoot {
    param([string]$NewPath)
    if ([string]::IsNullOrWhiteSpace($NewPath)) { Write-Host (Get-PvmHome); return }
    $oldRoot = Get-PvmHome
    if ($oldRoot -eq $NewPath) { Write-Host "PVM root is already: $NewPath" -ForegroundColor Yellow; return }
    if (-not (Test-Path $NewPath)) { New-Item -ItemType Directory -Path $NewPath -Force | Out-Null }
    if (Test-Path $oldRoot) {
        Write-Host "Migrating files..." -ForegroundColor Cyan
        Copy-Item -Path (Join-Path $oldRoot "versions") -Destination (Join-Path $NewPath "versions") -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path (Join-Path $oldRoot "settings.json") -Destination (Join-Path $NewPath "settings.json") -Force -ErrorAction SilentlyContinue
        Write-Host "Migration complete." -ForegroundColor Green
    }
    $settings = Get-Settings
    $settings.root = $NewPath
    Save-Settings $settings
    [Environment]::SetEnvironmentVariable("PVM_HOME", $NewPath, "User")
    $env:PVM_HOME = $NewPath
    Write-Host "PVM root changed to '$NewPath'" -ForegroundColor Green
}

function Invoke-PvmPythonMirror { param([string]$NewMirror) if ([string]::IsNullOrWhiteSpace($NewMirror)) { Write-Host (Get-PythonMirror) } elseif ($NewMirror -eq "default") { $s = Get-Settings; $s.python_mirror = $null; Save-Settings $s; Write-Host "Python mirror reset to default: $script:NPM_MIRROR_PYTHON" -ForegroundColor Green } else { $s = Get-Settings; $s.python_mirror = $NewMirror; Save-Settings $s; Write-Host "Python mirror set to: $NewMirror" -ForegroundColor Green } }
function Invoke-PvmPipMirror { param([string]$NewMirror) if ([string]::IsNullOrWhiteSpace($NewMirror)) { Write-Host (Get-PipMirror) } elseif ($NewMirror -eq "default") { $s = Get-Settings; $s.pip_mirror = $null; Save-Settings $s; Write-Host "pip mirror reset to default: $script:NPM_MIRROR_PIP" -ForegroundColor Green } else { $s = Get-Settings; $s.pip_mirror = $NewMirror; Save-Settings $s; Write-Host "pip mirror set to: $NewMirror" -ForegroundColor Green } }
function Invoke-PvmMirror { Write-Host "Python mirror: $(Get-PythonMirror)" -ForegroundColor Cyan; Write-Host "pip mirror:   $(Get-PipMirror)" -ForegroundColor Cyan }
function Invoke-PvmVersion { Write-Host "PVM version $script:PVM_VERSION" -ForegroundColor Cyan }
function Invoke-PvmHelp {
    Write-Host @"
PVM - Python Version Manager for Windows v$script:PVM_VERSION

Commands:
  install <version>       Install a Python version
  use <version>          Switch to a version
  list                   List installed versions
  list available [--check] List all available versions (use --check to show Windows support)
  current                Show current version
  uninstall <version>    Uninstall a version
  root [path]            Show/set PVM root
  python_mirror [url]  Show/set Python download mirror (use 'default' to reset)
  pip_mirror [url]       Show/set pip mirror (use 'default' to reset)
  mirror                 Show current mirror settings
  version                Show PVM version
  help                   Show this help

Version shortcuts:
  pvm install 3.12         ->  latest 3.12.x version
  pvm install latest       ->  latest stable version

Examples:
  pvm install 3.12.9
  pvm install 3.12
  pvm install latest
  pvm use 3.12.9
  pvm list available --check

Mirrors:
  pvm python_mirror $script:NPM_MIRROR_PYTHON
  pvm pip_mirror $script:NPM_MIRROR_PIP
"@ 
}

# ─── Main ────────────────────────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($Command)) { Invoke-PvmHelp; return }
switch ($Command.ToLower()) {
    "install"    { Invoke-PvmInstall $Arg1 $Arg2 }
    "use"        { Invoke-PvmUse $Arg1 }
    "list"       { 
        $checkFlag = ($Arg2 -eq "-check" -or $Arg2 -eq "--check")
        if ($RemainingArgs) {
            foreach ($arg in $RemainingArgs) {
                if ($arg -eq "-check" -or $arg -eq "--check") { $checkFlag = $true }
            }
        }
        if ($Arg1 -eq "available") { 
            if ($checkFlag) {
                Invoke-PvmList -Available -Check
            } else {
                Invoke-PvmList -Available
            }
        } else { 
            Invoke-PvmList 
        } 
    }
    "current"    { Invoke-PvmCurrent }
    "uninstall"  { Invoke-PvmUninstall $Arg1 }
    "root"       { Invoke-PvmRoot $Arg1 }
    "python_mirror" { Invoke-PvmPythonMirror $Arg1 }
    "pip_mirror" { Invoke-PvmPipMirror $Arg1 }
    "mirror"     { Invoke-PvmMirror }
    "version"    { Invoke-PvmVersion }
    "help"       { Invoke-PvmHelp }
    default      { Write-ColorOutput "Unknown command: $Command" "Red" }
}

