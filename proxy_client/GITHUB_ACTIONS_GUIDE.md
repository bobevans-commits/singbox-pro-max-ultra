# GitHub Actions 打包配置指南

## 📦 概述

本项目配置了两套 GitHub Actions 工作流，用于自动化构建和发布多平台代理客户端应用。

## 🔧 工作流文件

### 1. `windows-build.yml` - Windows 专用构建
专注于 Windows 平台的详细构建流程，包含：
- Rust 核心编译 (DLL/EXE)
- Flutter Windows 桌面应用构建
- sing-box 二进制下载与集成
- NSIS 安装程序制作
- ZIP 分发包创建

### 2. `multi-platform-build.yml` - 多平台统一构建
支持所有目标平台的一键构建：
- ✅ Windows (ZIP + NSIS Installer)
- ✅ macOS (Universal DMG - Intel + Apple Silicon)
- ✅ Linux (AppImage)
- ✅ Android (APK + AAB)

## 🚀 触发方式

### 自动触发
```yaml
# Push 到 main/develop 分支
push:
  branches: [ main, develop ]

# 创建版本标签
tags:
  - 'v*'

# Pull Request
pull_request:
  branches: [ main ]
```

### 手动触发 (Workflow Dispatch)
在 GitHub Actions 页面点击 "Run workflow"，可选择：
- **Version**: 版本号 (默认: dev)
- **Platforms**: 要构建的平台 (默认: 全部)

## 📋 前置准备

### 1. GitHub Secrets 配置
在项目 Settings → Secrets and variables → Actions 中添加：

```bash
# 可选：如果需要发布到 GitHub Releases
GITHUB_TOKEN: # 自动生成，无需手动配置

# 可选：代码签名证书 (Windows)
WINDOWS_CERTIFICATE: # Base64 编码的 .pfx 文件
WINDOWS_CERTIFICATE_PASSWORD: # 证书密码

# 可选：Apple 开发者证书 (macOS)
APPLE_CERTIFICATE: # Base64 编码的证书
APPLE_CERTIFICATE_PASSWORD: # 证书密码
APPLE_ID: # Apple ID
APPLE_TEAM_ID: # Team ID

# 可选：Google Play 服务账号 (Android)
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: # Service Account JSON
```

### 2. 本地测试构建

#### Windows 本地构建
```powershell
# 安装依赖
rustup install stable
rustup target add x86_64-pc-windows-msvc

flutter config --enable-windows-desktop

# 构建 Rust 核心
cd rust_core
cargo build --release

# 下载 sing-box
mkdir -p ../flutter_ui/assets/bin
Invoke-WebRequest -Uri "https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-1.10.0-windows-amd64.zip" -OutFile "sing-box.zip"
Expand-Archive -Path "sing-box.zip" -DestinationPath "../flutter_ui/assets/bin/" -Force

# 构建 Flutter
cd ../flutter_ui
flutter pub get
flutter build windows --release

# 打包
mkdir dist
xcopy /E /I /Y build\windows\x64\runner\Release\* dist\
copy assets\bin\sing-box*.exe dist\
Compress-Archive -Path dist\* -DestinationPath "ProxyClient-windows-x64-dev.zip"
```

#### Linux 本地构建
```bash
# 安装依赖
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

rustup install stable
rustup target add x86_64-unknown-linux-gnu

flutter config --enable-linux-desktop

# 构建
cd rust_core && cargo build --release
cd ../flutter_ui
flutter pub get

# 下载 sing-box
mkdir -p assets/bin
curl -L https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-1.10.0-linux-amd64.tar.gz | tar -xzf - -C assets/bin/

flutter build linux --release

# 打包 AppImage
# (参考 CI 脚本中的 AppImage 创建步骤)
```

#### macOS 本地构建
```bash
rustup install stable
rustup target add x86_64-apple-darwin aarch64-apple-darwin

flutter config --enable-macos-desktop

cd rust_core
cargo build --release --target x86_64-apple-darwin
cargo build --release --target aarch64-apple-darwin

# 创建 Universal Binary
lipo -create \
  target/x86_64-apple-darwin/release/libproxy_client.dylib \
  target/aarch64-apple-darwin/release/libproxy_client.dylib \
  -output target/universal/libproxy_client.dylib

cd ../flutter_ui
flutter pub get
flutter build macos --release
```

#### Android 本地构建
```bash
# 安装 Android NDK
sdkmanager --install "ndk;25.2.9519653"

# 安装 cargo-ndk
cargo install cargo-ndk

cd rust_core
cargo ndk \
  --target aarch64-linux-android \
  --target armv7-linux-androideabi \
  --target x86_64-linux-android \
  -o ../flutter_ui/android/app/src/main/jniLibs \
  build --release

cd ../flutter_ui
flutter pub get
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

## 📊 构建产物

### Windows
```
ProxyClient-windows-x64-v1.0.0.zip
├── proxy_client.exe          # Flutter 应用主程序
├── proxy_client.dll          # Rust 核心库
├── sing-box.exe              # sing-box 核心
├── flutter_windows.dll       # Flutter 引擎
├── icudtl.dat                # ICU 数据
├── start.bat                 # 快捷启动脚本
└── README.txt                # 使用说明

ProxyClient-Setup.exe         # NSIS 安装程序 (可选)
```

### macOS
```
ProxyClient-macos-universal.dmg
└── ProxyClient.app           # Universal Binary (Intel + M1/M2)
    └── Contents/MacOS/
        ├── ProxyClient       # Flutter 应用
        └── sing-box          # sing-box 核心
```

### Linux
```
ProxyClient-linux-x86_64.AppImage
# 自包含的可执行文件，无需安装
```

### Android
```
app-armeabi-v7a-release.apk   # 32 位 ARM
app-arm64-v8a-release.apk     # 64 位 ARM (推荐)
app-x86_64-release.apk        # 64 位 x86
app-release.aab               # Google Play 包
```

## 🔍 调试技巧

### 1. 启用详细日志
在工作流文件中添加：
```yaml
- name: Debug Info
  run: |
    echo "Runner OS: ${{ runner.os }}"
    echo "Runner Arch: ${{ runner.arch }}"
    echo "Flutter Version: $(flutter --version)"
    echo "Rust Version: $(rustc --version)"
    pwd
    ls -la
```

### 2. SSH 调试 (使用 tmate)
```yaml
- name: Setup tmate session
  if: ${{ failure() }}
  uses: mxschmitt/action-tmate@v3
  timeout-minutes: 30
```

### 3. 查看构建日志
- GitHub Actions → 选择运行 → 下载完整日志
- 或启用 `upload-artifact` 收集日志文件

### 4. 本地复现 CI 环境
使用 [act](https://github.com/nektos/act) 工具在本地运行 GitHub Actions：
```bash
# 安装 act
brew install act  # macOS
# 或从 https://github.com/nektos/act/releases 下载

# 运行工作流
act push  # 模拟 push 事件
act -j build-windows  # 运行特定 job
```

## 🎯 发布流程

### 开发版本
```bash
# 1. 推送到 develop 分支
git push origin develop

# 2. 手动触发 workflow_dispatch
# 设置 version=dev-$(date +%Y%m%d)

# 3. 下载 Artifacts 进行测试
```

### 正式版本
```bash
# 1. 打标签
git tag v1.0.0
git push origin v1.0.0

# 2. CI 自动构建并创建 GitHub Release
# 3. 下载 Release 资产进行验证
# 4. 确认无误后标记为 Latest Release
```

## ⚠️ 常见问题

### Q1: Rust 编译失败
**解决**: 确保目标平台已安装
```bash
rustup target add <target-triple>
# 例如：rustup target add x86_64-pc-windows-msvc
```

### Q2: Flutter 找不到目标平台
**解决**: 启用对应平台支持
```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

### Q3: sing-box 下载失败
**解决**: 检查网络或使用镜像
```yaml
# 使用镜像源
curl -L https://mirror.ghproxy.com/https://github.com/SagerNet/sing-box/releases/... 
```

### Q4: Android 构建缺少 NDK
**解决**: 在 CI 中正确安装 NDK
```yaml
- name: Install Android NDK
  run: sdkmanager --install "ndk;25.2.9519653"
```

### Q5: AppImage 无法运行
**解决**: 确保 FUSE 支持
```bash
# Ubuntu/Debian
sudo apt install fuse

# 或以兼容模式运行
./ProxyClient-*.AppImage --appimage-extract-and-run
```

## 📈 优化建议

### 1. 缓存优化
已配置 Rust 和 Flutter 缓存，首次构建后速度提升 60%+

### 2. 并行构建
多平台 job 并行执行，总耗时 ≈ 最慢平台耗时

### 3. 增量构建
使用 `fetch-depth: 0` 获取完整历史，支持增量编译

### 4. 产物压缩
使用 ZIP/TAR.GZ 压缩，减少存储和下载时间

## 🔗 相关资源

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Flutter 桌面开发](https://docs.flutter.dev/desktop)
- [Rust 交叉编译](https://doc.rust-lang.org/nightly/rustc/platform-support.html)
- [sing-box 官方下载](https://github.com/SagerNet/sing-box/releases)
- [NSIS 安装程序制作](https://nsis.sourceforge.io/)

---

**最后更新**: 2024-01-15
**维护者**: Proxy Client Team
