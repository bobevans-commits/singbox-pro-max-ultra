# 快速开始指南 - Windows 本地构建与测试

本指南帮助您在 Windows 上快速构建和测试 Proxy Client 应用。

## 📋 前置要求

### 1. 安装 Rust
```powershell
# 下载并运行 rustup-init.exe
# 或访问 https://rustup.rs/

# 验证安装
rustc --version
cargo --version
```

### 2. 安装 Flutter
```powershell
# 下载 Flutter SDK
# 访问 https://docs.flutter.dev/get-started/install/windows

# 解压到 C:\src\flutter 或其他目录
# 添加 flutter/bin 到 PATH

# 验证安装
flutter doctor
flutter config --enable-windows-desktop
```

### 3. 安装 Visual Studio Build Tools
```powershell
# 下载 Visual Studio Build Tools 2022
# 访问 https://visualstudio.microsoft.com/visual-cpp-build-tools/

# 安装时选择 "Desktop development with C++"
# 确保包含 Windows 10/11 SDK
```

### 4. 安装 Git
```powershell
# 下载 Git for Windows
# 访问 https://git-scm.com/download/win
```

## 🚀 快速构建步骤

### Step 1: 克隆项目
```powershell
cd C:\Projects
git clone https://github.com/your-username/proxy_client.git
cd proxy_client
```

### Step 2: 构建 Rust 核心
```powershell
cd rust_core

# 构建 Release 版本
cargo build --release

# 验证构建产物
ls target\release\
# 应该看到 proxy_client.dll 和/或 proxy_client.exe
```

### Step 3: 下载 sing-box 核心
```powershell
cd ..\flutter_ui

# 创建 assets 目录
mkdir -p assets\bin

# 下载 sing-box (使用 PowerShell)
$url = "https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-1.10.0-windows-amd64.zip"
Invoke-WebRequest -Uri $url -OutFile "sing-box.zip"

# 解压
Expand-Archive -Path "sing-box.zip" -DestinationPath "assets\bin\" -Force

# 验证
ls assets\bin\
# 应该看到 sing-box.exe
```

### Step 4: 获取 Flutter 依赖
```powershell
cd flutter_ui
flutter pub get
```

### Step 5: 运行开发版本
```powershell
# 直接运行（热重载支持）
flutter run -d windows

# 或构建 Release 版本
flutter build windows --release
```

### Step 6: 打包分发
```powershell
# 创建分发目录
mkdir dist

# 复制 Flutter 构建产物
xcopy /E /I /Y build\windows\x64\runner\Release\* dist\

# 复制 sing-box
copy assets\bin\sing-box.exe dist\

# 复制 Rust 核心 DLL
copy ..\rust_core\target\release\proxy_client.dll dist\

# 创建启动脚本
@"
@echo off
echo Starting Proxy Client...
start "" "proxy_client.exe"
exit
"@ | Out-File -FilePath "dist\start.bat" -Encoding ASCII

# 创建 README
@"
# Proxy Client for Windows

## 使用方法
1. 运行 proxy_client.exe 或 start.bat
2. 导入配置文件 (JSON/YAML)
3. 选择节点并点击连接
4. 如需系统代理，启用 TUN 模式

## 注意事项
- 需要 Windows 10/11 64 位
- TUN 模式需要管理员权限
"@ | Out-File -FilePath "dist\README.txt" -Encoding ASCII

# 打包为 ZIP
Compress-Archive -Path dist\* -DestinationPath "ProxyClient-windows-x64-dev.zip"

echo "构建完成！文件：ProxyClient-windows-x64-dev.zip"
```

## 🧪 测试功能

### 单元测试
```powershell
cd flutter_ui
flutter test

# Rust 测试
cd ..\rust_core
cargo test
```

### 手动测试清单

#### 基础功能
- [ ] 应用正常启动
- [ ] UI 渲染正常（无乱码、错位）
- [ ] 可以导入配置文件
- [ ] 节点列表显示正确

#### 协议支持
- [ ] Shadowsocks 节点可连接
- [ ] VMess 节点可连接
- [ ] Trojan 节点可连接
- [ ] VLESS 节点可连接
- [ ] Hysteria2 节点可连接
- [ ] TUIC 节点可连接

#### 路由功能
- [ ] 规则匹配正常
- [ ] GeoSite 规则生效
- [ ] GeoIP 规则生效
- [ ] 自定义规则生效

#### DNS 功能
- [ ] Split DNS 配置正确
- [ ] DoH/DoT/DoQ 可用
- [ ] FakeIP 模式工作正常

#### 系统集成功能
- [ ] TUN 模式可启用（需管理员）
- [ ] 系统代理设置生效
- [ ] 托盘图标显示正常
- [ ] 开机自启可选

#### 性能测试
- [ ] 延迟测试准确
- [ ] 速度测试正常
- [ ] 内存占用合理 (<200MB)
- [ ] CPU 占用低 (<5% 空闲时)

## 🔧 故障排除

### 问题 1: Flutter 找不到 Windows 平台
**错误**: `No supported devices found with name or id 'windows'`

**解决**:
```powershell
flutter config --enable-windows-desktop
flutter doctor
# 确保 Windows 显示为 ✓
```

### 问题 2: Rust 编译失败
**错误**: `error: linker 'link.exe' not found`

**解决**:
```powershell
# 安装 Visual Studio Build Tools
# 确保安装了 "Desktop development with C++" 工作负载

# 或在开发者命令提示符中运行
cargo clean
cargo build --release
```

### 问题 3: 缺少 DLL 文件
**错误**: `The code execution cannot proceed because flutter_windows.dll was not found`

**解决**:
```powershell
# 确保复制了所有必要的文件
ls build\windows\x64\runner\Release\
# 必须包含：
# - proxy_client.exe
# - flutter_windows.dll
# - icudtl.dat
# - proxy_client.dll (Rust 核心)
```

### 问题 4: sing-box 无法启动
**错误**: `Failed to start sing-box core`

**解决**:
```powershell
# 检查 sing-box 是否存在
ls assets\bin\sing-box.exe

# 测试 sing-box
.\assets\bin\sing-box.exe version

# 检查配置文件格式
.\assets\bin\sing-box.exe check -c config.json
```

### 问题 5: TUN 模式无法启用
**错误**: `Permission denied` 或 `Access denied`

**解决**:
```powershell
# 以管理员身份运行应用
# 右键点击 proxy_client.exe → "以管理员身份运行"

# 或在 PowerShell 中
Start-Process .\proxy_client.exe -Verb RunAs
```

## 📊 性能优化建议

### 开发环境
```powershell
# 使用 Debug 模式快速迭代
flutter run -d windows

# 启用热重载
# 按 r 键在终端中热重载
```

### 生产环境
```powershell
# 使用 Release 模式
flutter build windows --release

# 启用 Dart 代码混淆（可选）
flutter build windows --release --obfuscate --split-debug-info=symbols

# 压缩产物
Compress-Archive -Path dist\* -DestinationPath "ProxyClient-windows-x64-v1.0.0.zip" -CompressionLevel Optimal
```

## 📝 配置文件示例

创建 `config.json` 进行测试：

```json
{
  "log": {
    "level": "info",
    "output": "proxy_client.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 7890
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "selector",
      "tag": "proxy",
      "outbounds": ["node1", "node2"]
    },
    {
      "type": "shadowsocks",
      "tag": "node1",
      "server": "example.com",
      "server_port": 443,
      "method": "aes-256-gcm",
      "password": "your_password"
    }
  ],
  "route": {
    "rules": [
      {
        "domain": ["google.com"],
        "outbound": "proxy"
      }
    ]
  }
}
```

## 🎯 下一步

1. **自动化测试**: 参考 `GITHUB_ACTIONS_GUIDE.md` 配置 CI/CD
2. **代码签名**: 购买代码签名证书，避免 Windows SmartScreen 警告
3. **安装程序**: 使用 NSIS 或 Inno Setup 制作安装包
4. **自动更新**: 实现应用内自动更新功能
5. **多语言**: 添加 i18n 支持

---

**文档版本**: 1.0.0  
**最后更新**: 2024-01-15  
**适用平台**: Windows 10/11 (64-bit)
