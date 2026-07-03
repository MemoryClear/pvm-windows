# PVM - Python Version Manager for Windows

Windows 上的 Python 版本管理工具，轻松安装、切换多个 Python 版本。

A lightweight Python version manager for Windows. Install and switch between multiple Python versions with zero registry pollution.

## 特性 / Features

- ✅ 无需管理员权限 / No admin rights required
- ✅ 零注册表污染 / Zero registry pollution (embeddable packages)
- ✅ 自动 PATH 管理 / Automatic PATH management
- ✅ 国内镜像支持 / China mirror support (npmmirror, Tsinghua)
- ✅ 版本别名 / Version aliases (latest, newest)
- ✅ 部分版本匹配 / Partial version matching (3.12 → 3.12.9)
- ✅ 纯 PowerShell 实现 / Pure PowerShell, zero dependencies

## 快速开始 / Quick Start

```powershell
# 安装 PVM / Install PVM
powershell -ExecutionPolicy Bypass -File install.ps1

# 设置国内镜像（推荐）/ Set China mirror (recommended)
pvm python_mirror https://registry.npmmirror.com/-/binary/python/
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/

# 安装 Python / Install Python
pvm install latest

# 切换版本 / Switch versions
pvm use 3.12.9

# 查看已安装版本 / List installed versions
pvm list
```

## 系统要求 / Requirements

- Windows 10/11
- PowerShell 5.1+

## 许可证 / License

MIT License

## 致谢 / Acknowledgments

- 灵感来自 [nvm-windows](https://github.com/coreybutler/nvm-windows)
- Inspired by [nvm-windows](https://github.com/coreybutler/nvm-windows)
