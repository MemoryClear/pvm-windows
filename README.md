# PVM - Python Version Manager for Windows

<div align="center">

**Manage multiple Python installations on Windows**

*Inspired by [nvm-windows](https://github.com/coreybutler/nvm-windows)*

</div>

---

## 📖 Overview

PVM (Python Version Manager) is a lightweight tool for managing multiple Python versions on Windows. It allows you to easily install, switch between, and manage different Python versions without conflicts.

### Features

- ✅ **No admin rights required** - Pure user-space installation
- ✅ **Embeddable Python** - Uses official embeddable zip packages, no registry pollution
- ✅ **Automatic PATH management** - PVM paths take priority over system Python
- ✅ **China mirror support** - Built-in support for npmmirror and Tsinghua mirrors
- ✅ **Partial version matching** - Install `3.12` to get latest 3.12.x
- ✅ **Version aliases** - Use `latest`, `newest` shortcuts
- ✅ **Custom install directory** - Install Python versions anywhere with `pvm root`
- ✅ **Zero dependencies** - Pure PowerShell, works on Windows 10/11
- ✅ **Reliable pip install** - stdin pipe method bypasses execution policy issues

## 🚀 Quick Start

### Installation

1. Download **all three files** from this repository to the **same directory**:
   - `install.ps1` — installer
   - `pvm.ps1` — main script
   - `uninstall.ps1` — uninstaller

2. Run the installer:

```powershell
cd <directory-with-downloads>
powershell -ExecutionPolicy Bypass -File install.ps1
```

> ⚠️ All three files must be in the same directory before running `install.ps1`. The installer copies them to `%USERPROFILE%\.pvm\bin\`.

3. **Restart your terminal** (important!)
4. Verify installation:

```cmd
pvm version
```

### First Time Setup (China Users)

If you're in China, set mirrors first for faster downloads:

```cmd
pvm python_mirror https://registry.npmmirror.com/-/binary/python/
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/
```

### Install Python

```cmd
pvm install latest
```

That's it! You now have Python installed and ready to use.

### Example Output

```
> pvm install 3.12.9
Checking availability of Python 3.12.9 ...

Installing Python 3.12.9 (embeddable)...
Downloading : https://www.python.org/ftp/python/3.12.9/python-3.12.9-embed-amd64.zip
Extracting to: C:\Users\you\.pvm\versions\3.12.9
  Extracted: Python 3.12.9
  pip installed
Python 3.12.9 installed successfully!
```

## 📚 Usage

### Basic Commands

#### Install a Python version

```cmd
pvm install 3.12.9          # Install specific version
pvm install 3.12             # Install latest 3.12.x
pvm install latest           # Install latest stable version
```

**How it works:**
- Downloads official embeddable zip from python.org (or configured mirror)
- Extracts to `%PVM_HOME%\versions\<version>\`
- Fixes `python._pth` to enable `import site`
- Installs pip via stdin pipe (no temp files, no execution policy issues)

#### Switch between versions

```cmd
pvm use 3.12.9              # Switch to specific version
pvm use newest              # Switch to latest installed version
```

**What `pvm use` does:**
1. Creates a junction: `%PVM_HOME%\current` → `%PVM_HOME%\versions\<version>\`
2. Prepends `%PVM_HOME%\current` and `%PVM_HOME%\current\Scripts` to PATH
3. Updates both user PATH (persistent) and current session PATH

#### List versions

```cmd
pvm list                    # List installed versions
pvm list available          # List all available versions
pvm list available --check  # List available versions with Windows packages
pvm current                 # Show currently active version
```

**Example:**

```cmd
> pvm list
Installed versions:
  * 3.14.6 (active)
    3.13.14
    3.12.9
    3.11.9
```

#### Uninstall a version

```cmd
pvm uninstall 3.10.5        # Remove a specific version
```

**Note:** You cannot uninstall the currently active version. Switch to another version first.

### Directory Management

#### Change PVM home directory

```cmd
pvm root                      # Show current PVM home directory
pvm root D:\pvm               # Change PVM home (migrates data)
```

**What `pvm root <path>` does:**
1. Creates the new directory if it doesn't exist
2. Migrates existing data: `versions\`, `settings.json`, `available_versions.cache`
3. Updates `PVM_HOME` environment variable and PATH

#### Install PVM to custom directory

```powershell
# Install PVM to D:\pvm
powershell -ExecutionPolicy Bypass -File install.ps1 -InstallDir D:\pvm
```

### Mirror Configuration

```cmd
# Python download mirror
pvm python_mirror                                           # Show current
pvm python_mirror https://registry.npmmirror.com/-/binary/python/  # China mirror
pvm python_mirror default                                   # Reset to official

# pip mirror
pvm pip_mirror                                              # Show current
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/    # Tsinghua mirror
pvm pip_mirror default                                      # Reset to official

# View all mirrors
pvm mirror
```

### Other Commands

```cmd
pvm version                   # Show PVM version
pvm help                      # Show help message
```

## 🏗️ How It Works

### Directory Structure

```
%USERPROFILE%\.pvm\              (or custom PVM_HOME)
├── bin\
│   ├── pvm.ps1                  # Main script
│   ├── pvm.bat                  # Command wrapper
│   └── uninstall.ps1            # Uninstaller
├── versions\
│   ├── 3.12.9\                  # Python 3.12.9 (embeddable)
│   │   ├── python.exe
│   │   ├── python312._pth       # Path configuration (modified)
│   │   ├── Scripts\
│   │   │   ├── pip.exe
│   │   │   └── ...
│   │   └── ...
│   └── 3.11.9\
│       ├── python.exe
│       └── ...
├── current -> versions\3.12.9   # Junction to active version
├── settings.json                # Configuration (mirrors, root)
└── available_versions.cache     # Cached version list
```

### Embeddable Python Approach

PVM uses **embeddable zip packages** (not the full `.exe` installer):

**Advantages over exe installer:**
- ✅ No registry entries - zero system pollution
- ✅ No MSI conflicts - clean uninstall by deleting directory
- ✅ Portable - versions can be moved/copied freely
- ✅ Reliable - no installer quirks or TargetDir issues

**Post-extract steps:**
1. Fix `python._pth` - uncomment `import site` (enables `site-packages`)
2. Write with UTF-8 no BOM (prevents `encodings` module errors)
3. Install pip via stdin pipe (bypasses execution policy, no temp files)

### Version Switching Mechanism

PVM uses **directory junctions** (not symlinks) to switch versions:

1. Each version lives in `%PVM_HOME%\versions\<version>\`
2. `pvm use <version>` updates the `current` junction
3. PATH is prepended so PVM's Python takes priority over system Python
4. Uses `cmd /c rmdir` for reliable junction removal

## 🇨🇳 China Mirror Support

### Recommended Mirrors

| Service | URL |
|---------|-----|
| **Python (npmmirror)** | `https://registry.npmmirror.com/-/binary/python/` |
| **Python (Aliyun)** | `https://mirrors.aliyun.com/python/` |
| **pip (Tsinghua)** | `https://pypi.tuna.tsinghua.edu.cn/simple/` |
| **pip (Aliyun)** | `https://mirrors.aliyun.com/pypi/simple/` |
| **pip (Douban)** | `https://pypi.douban.com/simple/` |

### Quick Setup

```cmd
pvm python_mirror https://registry.npmmirror.com/-/binary/python/
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/
```

Settings persist in `settings.json`.

## 🔧 Advanced Usage

### Multiple Python Projects

```cmd
# Project A needs Python 3.11
cd project-a
pvm use 3.11.9
python -m venv venv

# Project B needs Python 3.12
cd ../project-b
pvm use 3.12.9
python -m venv venv
```

### Integration with IDEs

Point your IDE to the PVM `current` junction:

- **VS Code**: `"python.defaultInterpreterPath": "${env:USERPROFILE}\\.pvm\\current\\python.exe"`
- **PyCharm**: Set interpreter to `%USERPROFILE%\.pvm\current\python.exe`

When you run `pvm use`, the IDE will automatically use the new version.

### Using pip with PVM

```cmd
# Recommended (avoids conflicts with other Python tools)
python -m pip install requests

# Direct (if PATH is set correctly)
pip install requests

# Full path (always works)
%USERPROFILE%\.pvm\current\Scripts\pip.exe install requests
```

## 📊 Comparison with Alternatives

| Feature | PVM | pyenv-win | Official Installer |
|---------|-----|-----------|-------------------|
| **No admin required** | ✅ | ✅ | ❌ |
| **Easy version switching** | ✅ | ✅ | ❌ |
| **Multiple versions** | ✅ | ✅ | ⚠️ Manual PATH |
| **China mirror support** | ✅ Built-in | ⚠️ Config | ❌ |
| **pip included** | ✅ | ✅ | ✅ |
| **No registry pollution** | ✅ | ✅ | ❌ |
| **Dependencies** | None | Python required | None |
| **PATH priority** | ✅ Prepend | ⚠️ Shims | ❌ |
| **Size per version** | ~30MB | ~50MB | ~50MB |

### Why PVM?

- **Simpler than pyenv-win** - No shims, no Python dependency
- **Cleaner than exe installer** - No registry, no MSI, just directories
- **China-friendly** - Built-in mirror configuration
- **Lightweight** - Pure PowerShell, zero dependencies
- **Reliable** - Embeddable zips avoid installer quirks

## 🐛 Troubleshooting

### "pvm is not recognized"

1. Restart your terminal after installation
2. Check PATH: `echo %PATH%` should include `%USERPROFILE%\.pvm\bin`
3. Force add: `set PATH=%USERPROFILE%\.pvm\bin;%PATH%`

### "No module named 'encodings'"

Usually caused by `PYTHONHOME` pointing elsewhere:

```cmd
set PYTHONHOME=
set PYTHONPATH=
pvm use <version>
```

### Download fails (404)

Some versions don't have embeddable zips. Check availability:

```cmd
pvm list available --check
```

Switch to China mirror if needed:

```cmd
pvm python_mirror https://registry.npmmirror.com/-/binary/python/
```

### pip install fails

```cmd
# Use python -m pip to avoid PATH conflicts
python -m pip install <package>

# Or check pip mirror
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/
```

### Junction issues (version switching fails)

```cmd
# Check current junction
dir %PVM_HOME%
# Should show: current -> D:\pvm\versions\3.12.9

# Force re-switch
pvm use <version>
```

## 📝 Uninstallation

### Quick uninstall (removes everything)

```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.pvm\bin\uninstall.ps1"
```

This removes:
- All installed Python versions
- PVM scripts and configuration
- `PVM_HOME` environment variable
- PVM entries from PATH (bin, current, current\Scripts)

### Manual uninstall

```cmd
# 1. Remove all versions
pvm list
pvm uninstall <version>     # Repeat for each (switch active first)

# 2. Run uninstaller
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.pvm\bin\uninstall.ps1"
```

## 🤝 Contributing

Contributions welcome! Ideas:

- [ ] Add support for 32-bit Python
- [ ] Pre-release version support
- [ ] Progress bar during download
- [ ] Proxy support
- [ ] GUI wrapper
- [ ] Per-version custom directories (`pvm install <ver> --dir <path>`)
- [ ] Auto venv creation (`pvm venv create`)
- [ ] `.python-version` file support

## 📄 License

MIT License

## 🙏 Acknowledgments

- Inspired by [nvm-windows](https://github.com/coreybutler/nvm-windows)
- Python embeddable packages from [python.org](https://www.python.org)
- China mirrors via [npmmirror](https://npmmirror.com) and [Tsinghua TUNA](https://mirrors.tuna.tsinghua.edu.cn)

---

<div align="center">

**Happy coding! 🐍**

</div>
