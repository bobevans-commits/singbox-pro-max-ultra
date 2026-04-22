# GitHub Actions CI/CD 配置指南

本文档详细说明如何配置和使用本项目的自动化构建与发布系统。

## 📁 项目结构

```
proxy_app/
├── .github/
│   └── workflows/
│       ├── multi-platform-build.yml    # 多平台构建主流程
│       └── windows-build.yml           # Windows 专用构建
├── scripts/
│   ├── download_kernels.sh             # 内核下载脚本
│   ├── build_windows.ps1               # Windows 构建脚本
│   ├── build_linux.sh                  # Linux 构建脚本
│   └── create_dmg.sh                   # macOS DMG 创建脚本
├── flutter_ui/
│   └── android/
│       └── key.properties              # Android 签名配置（模板）
└── README.md
```

## 🔐 GitHub Secrets 配置

在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中添加以下 Secrets：

### 必需配置

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `ANDROID_KEYSTORE` | Android 签名密钥库（Base64 编码） | `LS0tLS1CRUdJTiB...` |
| `ANDROID_KEY_PASSWORD` | 密钥库密码 | `your_password` |
| `ANDROID_KEY_ALIAS` | 密钥别名 | `upload` |

### 可选配置

| Secret 名称 | 说明 | 用途 |
|------------|------|------|
| `WINDOWS_CERTIFICATE` | Windows 代码签名证书（PFX，Base64） | 签名 Windows EXE |
| `WINDOWS_CERT_PASSWORD` | Windows 证书密码 | - |
| `APPLE_DEVELOPER_ID` | Apple 开发者 ID | `Developer ID Application: ...` |
| `APPLE_ID` | Apple ID | `your@apple.id` |
| `APPLE_APP_PASSWORD` | Apple 应用专用密码 | 用于 notarization |
| `APPLE_TEAM_ID` | Apple Team ID | `XXXXXXXXXX` |

## 📱 生成 Android 签名密钥库

```bash
# 生成新的 keystore
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload -storepass YOUR_PASSWORD \
  -keypass YOUR_PASSWORD \
  -dname "CN=Your Name, OU=Your Org, O=Your Org, L=City, ST=State, C=US"

# 将 keystore 转换为 Base64（用于 GitHub Secrets）
base64 -w 0 upload-keystore.jks > keystore_base64.txt
# 复制 keystore_base64.txt 的内容到 ANDROID_KEYSTORE
```

## 🚀 触发构建

### 自动触发

- **Push 到 main/develop 分支**: 自动开始构建
- **创建 Tag** (格式 `v*`): 构建并发布到 GitHub Releases
- **Pull Request**: 运行测试和构建验证

### 手动触发

1. 进入仓库的 **Actions** 标签
2. 选择 **"Multi-Platform Build"** 工作流
3. 点击 **"Run workflow"**
4. 填写参数：
   - `version`: 版本号（如 `v1.0.0` 或 `dev`）
   - `platforms`: 要构建的平台（逗号分隔：`windows,macos,linux,android`）
5. 点击 **"Run workflow"**

## 📦 构建产物

构建完成后，产物将上传到：

1. **GitHub Actions Artifacts** (保留 30 天)
   - 进入 Actions → 对应构建任务 → 下载 artifacts
   
2. **GitHub Releases** (仅 Tag 触发)
   - 访问 `https://github.com/你的用户名/你的仓库/releases`
   - 包含所有平台的安装包

### 产物文件命名

| 平台 | 文件名格式 | 说明 |
|------|-----------|------|
| Windows | `ProxyClient-windows-x64-v1.0.0.zip` | 绿色免安装版 |
| macOS | `ProxyClient-macos-universal.dmg` | 支持 Intel/Apple Silicon |
| Linux | `ProxyClient-linux-x86_64.AppImage` | AppImage 通用包 |
| Linux | `ProxyClient_v1.0.0_amd64.deb` | Debian/Ubuntu 包 |
| Android | `app-armeabi-v7a-release.apk` | ARMv7 设备 |
| Android | `app-arm64-v8a-release.apk` | ARM64 设备 |
| Android | `app-x86_64-release.apk` | x86_64 模拟器 |
| Android | `app-release.aab` | Google Play 包 |

## 🔧 自定义构建

### 修改内核版本

编辑 `scripts/download_kernels.sh`：

```bash
SINGBOX_VERSION="1.10.0"      # 修改 sing-box 版本
MIHOMO_VERSION="1.18.0"       # 修改 mihomo 版本
V2RAY_VERSION="5.13.0"        # 修改 v2ray 版本
```

### 添加新平台

1. 在 `.github/workflows/multi-platform-build.yml` 添加新的 job
2. 创建对应的构建脚本到 `scripts/`
3. 更新工作流的 `platforms` 输入选项

### 本地测试构建

```bash
# Windows
.\scripts\build_windows.ps1 -Version "v1.0.0"

# Linux
bash scripts/build_linux.sh v1.0.0

# macOS
bash scripts/create_dmg.sh v1.0.0

# 仅下载内核
bash scripts/download_kernels.sh ./flutter_ui/assets/bin
```

## ⚠️ 常见问题

### 1. Android 构建失败：签名错误

**症状**: `Keystore was tampered with, or password was incorrect`

**解决**:
- 检查 `ANDROID_KEYSTORE` 是否正确 Base64 编码
- 确认密码 secrets 正确
- 确保 `key.properties` 中的 alias 与实际一致

### 2. 内核下载超时

**症状**: `curl: (28) Failed to connect to github.com port 443: Connection timed out`

**解决**:
- GitHub Actions 网络问题，重试构建
- 使用国内镜像源（修改脚本中的 URL）
- 增加 curl 超时时间

### 3. Windows 签名失败

**症状**: `signtool.exe: Error: SignerSign() failed.`

**解决**:
- 确认证书未过期
- 检查 `WINDOWS_CERTIFICATE` 和 `WINDOWS_CERT_PASSWORD`
- 确保时间服务器可访问

### 4. macOS Notarization 失败

**症状**: `notarytool: ERROR: The request was not authorized.`

**解决**:
- 生成 Apple 应用专用密码：https://appleid.apple.com
- 设置 `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`
- 确保应用已正确签名

## 📊 构建优化

### 缓存策略

工作流已配置自动缓存：
- Flutter 依赖
- Rust crates
- Gradle 包
- 内核文件

### 并行构建

所有平台并行执行，总构建时间取决于最慢的平台（通常是 Android）。

### 减少构建时间

1. 定期清理旧 artifacts
2. 使用自托管 Runner（更快的网络和硬件）
3. 按需选择构建平台

## 📝 更新日志

每次 Release 会自动生成更新日志，格式：

```markdown
## Proxy Client v1.0.0

### Downloads
- **Windows**: `ProxyClient-windows-x64-v1.0.0.zip`
- **macOS**: `ProxyClient-macos-universal.dmg`
- ...

### Features
- ✅ sing-box core integration
- ✅ TUN mode support
- ...

### Changelog
[Auto-generated from git commits]
```

---

**最后更新**: 2024 年 1 月  
**维护者**: Proxy Client Team
