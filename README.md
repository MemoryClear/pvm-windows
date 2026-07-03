# PVM - Python 版本管理器 (Windows)

<div align="center">

**在 Windows 上轻松管理多个 Python 版本**

*灵感来自 [nvm-windows](https://github.com/coreybutler/nvm-windows)*

[English](README.md) | [中文](README_zh-CN.md)

</div>

---

## 📖 概述

PVM (Python Version Manager) 是一个轻量级的 Windows Python 版本管理工具，可以轻松安装、切换和管理多个 Python 版本，避免版本冲突。

### ✨ 特性

- ✅ **无需管理员权限** - 纯用户空间安装
- ✅ **嵌入式 Python** - 使用官方 embeddable zip 包，无注册表污染
- ✅ **自动 PATH 管理** - PVM 路径优先于系统 Python
- ✅ **国内镜像支持** - 内置 npmmirror 和清华镜像支持
- ✅ **部分版本匹配** - 安装 `3.12` 自动获取最新 3.12.x
- ✅ **版本别名** - 支持 `latest`、`newest` 快捷方式
- ✅ **自定义安装目录** - 使用 `pvm root` 随意安装
- ✅ **零依赖** - 纯 PowerShell 实现，支持 Windows 10/11
- ✅ **可靠的 pip 安装** - stdin pipe 方法绕过执行策略限制

## 🚀 快速开始

### 安装

1. 下载仓库中**所有三个文件**到**同一目录**：
   - `install.ps1` — 安装脚本
   - `pvm.ps1` — 主脚本
   - `uninstall.ps1` — 卸载脚本

2. 运行安装程序：

```powershell
cd <下载目录>
powershell -ExecutionPolicy Bypass -File install.ps1
```

> ⚠️ 运行 `install.ps1` 前，三个文件必须在同一目录。安装程序会将它们复制到 `%USERPROFILE%\.pvm\bin\`。

3. **重启终端**（重要！）
4. 验证安装：

```cmd
pvm version
```

### 国内用户首次设置

如果你在中国，建议先设置镜像加速下载：

```cmd
pvm python_mirror https://registry.npmmirror.com/-/binary/python/
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/
```

### 安装 Python

```cmd
pvm install latest
```

就这么简单！Python 已安装并可以使用。

### 示例输出

```
> pvm install 3.12.9
Checking availability of Python 3.12.9 ...

Installing Python 3.12.9 (embeddable)...
Downloading : https://registry.npmmirror.com/-/binary/python/3.12.9/python-3.12.9-embed-amd64.zip
Extracting to: C:\Users\you\.pvm\versions\3.12.9
  Extracted: Python 3.12.9
  pip installed
Python 3.12.9 installed successfully!
```

## 📚 使用方法

### 基本命令

#### 安装 Python 版本

```cmd
pvm install 3.12.9          # 安装指定版本
pvm install 3.12             # 安装最新 3.12.x
pvm install latest           # 安装最新稳定版
```

**工作原理：**
- 从 python.org 或配置的镜像下载官方 embeddable zip
- 解压到 `%PVM_HOME%\versions\<version>\`
- 修复 `python._pth` 启用 `import site`
- 通过 stdin pipe 安装 pip（无临时文件，无执行策略问题）

#### 切换版本

```cmd
pvm use 3.12.9              # 切换到指定版本
pvm use newest              # 切换到最新安装版本
```

**`pvm use` 执行的操作：**
1. 创建目录连接：`%PVM_HOME%\current` → `%PVM_HOME%\versions\<version>\`
2. 将 `%PVM_HOME%\current` 和 `%PVM_HOME%\current\Scripts` 添加到 PATH 开头
3. 同时更新用户 PATH（持久化）和当前会话 PATH

#### 列出版本

```cmd
pvm list                    # 列出已安装版本
pvm list available          # 列出所有可用版本
pvm list available --check  # 列出有 Windows 包的可用版本
pvm current                 # 显示当前激活版本
```

**示例：**

```cmd
> pvm list
Installed versions:
  * 3.14.6 (active)
    3.13.14
    3.12.9
    3.11.9
```

#### 卸载版本

```cmd
pvm uninstall 3.10.5        # 删除指定版本
```

**注意：** 不能卸载当前激活的版本，请先切换到其他版本。

### 目录管理

#### 更改 PVM 主目录

```cmd
pvm root                      # 显示当前 PVM 主目录
pvm root D:\pvm               # 更改 PVM 主目录（迁移数据）
```

**`pvm root <path>` 执行的操作：**
1. 如果不存在则创建新目录
2. 迁移现有数据：`versions\`、`settings.json`、`available_versions.cache`
3. 更新 `PVM_HOME` 环境变量和 PATH

#### 安装 PVM 到自定义目录

```powershell
# 安装 PVM 到 D:\pvm
powershell -ExecutionPolicy Bypass -File install.ps1 -InstallDir D:\pvm
```

### 镜像配置

```cmd
# Python 下载镜像
pvm python_mirror                                           # 显示当前
pvm python_mirror https://registry.npmmirror.com/-/binary/python/  # 国内镜像
pvm python_mirror default                                   # 重置为官方

# pip 镜像
pvm pip_mirror                                              # 显示当前
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/    # 清华镜像
pvm pip_mirror default                                      # 重置为官方

# 查看所有镜像
pvm mirror
```

### 其他命令

```cmd
pvm version                   # 显示 PVM 版本
pvm help                      # 显示帮助信息
```

## 🏗️ 工作原理

### 目录结构

```
%USERPROFILE%\.pvm\              （或自定义 PVM_HOME）
├── bin\
│   ├── pvm.ps1                  # 主脚本
│   ├── pvm.bat                  # 命令包装器
│   └── uninstall.ps1            # 卸载脚本
├── versions\
│   ├── 3.12.9\                  # Python 3.12.9（嵌入式）
│   │   ├── python.exe
│   │   ├── python312._pth       # 路径配置（已修改）
│   │   ├── Scripts\
│   │   │   ├── pip.exe
│   │   │   └── ...
│   │   └── ...
│   └── 3.11.9\
│       ├── python.exe
│       └── ...
├── current -> versions\3.12.9   # 指向激活版本的连接
├── settings.json                # 配置（镜像、主目录）
└── available_versions.cache     # 缓存的版本列表
```

### 嵌入式 Python 方案

PVM 使用 **embeddable zip 包**（而非完整的 `.exe` 安装程序）：

**相比 exe 安装程序的优势：**
- ✅ 无注册表条目 - 零系统污染
- ✅ 无 MSI 冲突 - 删除目录即可干净卸载
- ✅ 可移植 - 版本可自由移动/复制
- ✅ 可靠 - 无安装程序怪癖或 TargetDir 问题

**解压后步骤：**
1. 修复 `python._pth` - 取消注释 `import site`（启用 `site-packages`）
2. 使用 UTF-8 无 BOM 写入（防止 `encodings` 模块错误）
3. 通过 stdin pipe 安装 pip（绕过执行策略，无临时文件）

### 版本切换机制

PVM 使用**目录连接**（而非符号链接）切换版本：

1. 每个版本存放在 `%PVM_HOME%\versions\<version>\`
2. `pvm use <version>` 更新 `current` 连接
3. PATH 前置使 PVM 的 Python 优先于系统 Python
4. 使用 `cmd /c rmdir` 可靠删除连接

## 🇨🇳 国内镜像支持

### 推荐镜像

| 服务 | URL |
|---------|-----|
| **Python (npmmirror)** | `https://registry.npmmirror.com/-/binary/python/` |
| **Python (阿里云)** | `https://mirrors.aliyun.com/python/` |
| **pip (清华)** | `https://pypi.tuna.tsinghua.edu.cn/simple/` |
| **pip (阿里云)** | `https://mirrors.aliyun.com/pypi/simple/` |
| **pip (豆瓣)** | `https://pypi.douban.com/simple/` |

### 快速设置

```cmd
pvm python_mirror https://registry.npmmirror.com/-/binary/python/
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/
```

设置保存在 `settings.json` 中。

## 🔧 进阶用法

### 多个 Python 项目

```cmd
# 项目 A 需要 Python 3.11
cd project-a
pvm use 3.11.9
python -m venv venv

# 项目 B 需要 Python 3.12
cd ../project-b
pvm use 3.12.9
python -m venv venv
```

### 与 IDE 集成

将 IDE 指向 PVM `current` 连接：

- **VS Code**：`"python.defaultInterpreterPath": "${env:USERPROFILE}\\.pvm\\current\\python.exe"`
- **PyCharm**：设置解释器为 `%USERPROFILE%\.pvm\current\python.exe`

运行 `pvm use` 后，IDE 会自动使用新版本。

### 使用 pip

```cmd
# 推荐（避免与其他 Python 工具冲突）
python -m pip install requests

# 直接（如果 PATH 设置正确）
pip install requests

# 完整路径（始终有效）
%USERPROFILE%\.pvm\current\Scripts\pip.exe install requests
```

## 📊 与其他工具对比

| 特性 | PVM | pyenv-win | 官方安装程序 |
|---------|-----|-----------|-------------------|
| **无需管理员** | ✅ | ✅ | ❌ |
| **轻松切换版本** | ✅ | ✅ | ❌ |
| **多版本支持** | ✅ | ✅ | ⚠️ 手动 PATH |
| **国内镜像支持** | ✅ 内置 | ⚠️ 需配置 | ❌ |
| **包含 pip** | ✅ | ✅ | ✅ |
| **无注册表污染** | ✅ | ✅ | ❌ |
| **依赖** | 无 | 需要 Python | 无 |
| **PATH 优先级** | ✅ 前置 | ⚠️ Shims | ❌ |
| **每版本大小** | ~30MB | ~50MB | ~50MB |

### 为什么选择 PVM？

- **比 pyenv-win 更简单** - 无 shims，无 Python 依赖
- **比 exe 安装程序更干净** - 无注册表，无 MSI，只有目录
- **对国内用户友好** - 内置镜像配置
- **轻量级** - 纯 PowerShell，零依赖
- **可靠** - 嵌入式 zip 避免安装程序问题

## 🐛 故障排除

### "pvm 不是可识别的命令"

1. 安装后重启终端
2. 检查 PATH：`echo %PATH%` 应包含 `%USERPROFILE%\.pvm\bin`
3. 强制添加：`set PATH=%USERPROFILE%\.pvm\bin;%PATH%`

### "No module named 'encodings'"

通常由 `PYTHONHOME` 指向其他位置引起：

```cmd
set PYTHONHOME=
set PYTHONPATH=
pvm use <version>
```

### 下载失败 (404)

某些版本没有 embeddable zip。检查可用性：

```cmd
pvm list available --check
```

如需切换到国内镜像：

```cmd
pvm python_mirror https://registry.npmmirror.com/-/binary/python/
```

### pip 安装失败

```cmd
# 使用 python -m pip 避免 PATH 冲突
python -m pip install <package>

# 或检查 pip 镜像
pvm pip_mirror https://pypi.tuna.tsinghua.edu.cn/simple/
```

### 连接问题（版本切换失败）

```cmd
# 检查当前连接
dir %PVM_HOME%
# 应显示：current -> D:\pvm\versions\3.12.9

# 强制重新切换
pvm use <version>
```

## 📝 卸载

### 快速卸载（删除所有内容）

```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.pvm\bin\uninstall.ps1"
```

这会删除：
- 所有已安装的 Python 版本
- PVM 脚本和配置
- `PVM_HOME` 环境变量
- PATH 中的 PVM 条目（bin、current、current\Scripts）

### 手动卸载

```cmd
# 1. 删除所有版本
pvm list
pvm uninstall <version>     # 重复执行（先切换激活版本）

# 2. 运行卸载程序
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.pvm\bin\uninstall.ps1"
```

## 🤝 贡献

欢迎贡献！改进方向：

- [ ] 支持 32 位 Python
- [ ] 预发布版本支持
- [ ] 下载进度条
- [ ] 代理支持
- [ ] GUI 包装器
- [ ] 每版本自定义目录 (`pvm install <ver> --dir <path>`)
- [ ] 自动创建虚拟环境 (`pvm venv create`)
- [ ] `.python-version` 文件支持

## 📄 许可证

MIT License

## 🙏 致谢

- 灵感来自 [nvm-windows](https://github.com/coreybutler/nvm-windows)
- Python embeddable 包来自 [python.org](https://www.python.org)
- 国内镜像来自 [npmmirror](https://npmmirror.com) 和 [清华 TUNA](https://mirrors.tuna.tsinghua.edu.cn)

---

<div align="center">

**Happy coding! 🐍**

</div>
