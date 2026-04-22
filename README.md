# Proxy Client - 多平台代理客户端

[![Multi-Platform Build](https://github.com/your-username/proxy_client/actions/workflows/multi-platform-build.yml/badge.svg)](https://github.com/your-username/proxy_client/actions/workflows/multi-platform-build.yml)
[![Windows Build](https://github.com/your-username/proxy_client/actions/workflows/windows-build.yml/badge.svg)](https://github.com/your-username/proxy_client/actions/workflows/windows-build.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**一个基于 Rust + Flutter 的高性能跨平台代理客户端，支持 sing-box、mihomo、v2ray-core 多种内核。**

## ✨ 特性

### 🌐 协议支持
- **传统协议**: Shadowsocks (SS2022), VMess, Trojan, VLESS
- **高性能协议**: Hysteria/Hysteria2, TUIC, ShadowTLS, WireGuard
- **安全性**: VLESS-REALITY (完整 uTLS 指纹支持)

### 🎯 路由与流量管理
- **规则引擎**: 基于域名、IP(GeoIP)、GeoSite、端口、协议的分流
- **规则集**: 支持预编译二进制规则集，高速匹配
- **负载均衡**: selector(手动)/urltest(延迟测试)/weighted-round-robin

### 🔒 DNS 模块
- **高级协议**: DoH/DoT/DoQ/UDP/TCP 全支持
- **Split DNS**: 国内/国际查询智能分流
- **FakeIP**: TUN/透明代理模式优化

### 🖥️ 系统集成
- **TUN 模式**: 虚拟网卡拦截全系统流量
- **透明代理**: Linux TProxy/Redirect 原生支持
- **流量嗅探**: 加密流量域名/协议识别

### ⚡ 技术架构
- **核心引擎**: Rust 编写，多线程优化，低资源占用
- **热重载**: 配置更新不中断连接
- **多路复用**: Mux 协议减少握手开销
- **跨平台**: Windows/macOS/Linux/Android/iOS 统一体验

## 📦 安装

### Windows
```powershell
# 方法 1: 下载预编译版本
# 访问 https://github.com/your-username/proxy_client/releases
# 下载 ProxyClient-windows-x64-*.zip

# 方法 2: 本地构建
.\build.ps1 -Version v1.0.0
```

### macOS
```bash
# Homebrew (即将推出)
brew install proxy-client

# 或从 Releases 下载 DMG
```

### Linux
```bash
# AppImage (推荐)
chmod +x ProxyClient-linux-x86_64.AppImage
./ProxyClient-linux-x86_64.AppImage

# AUR (Arch Linux, 即将推出)
yay -S proxy-client
```

### Android
- 从 [Releases](https://github.com/your-username/proxy_client/releases) 下载 APK
- 或从 Google Play 获取 (即将推出)

## 🚀 快速开始

### 1. 导入配置
- 点击 "Import Config" 按钮
- 选择 JSON/YAML 配置文件
- 或粘贴订阅链接

### 2. 选择节点
- 在 Nodes 标签页浏览可用节点
- 点击节点进行选择
- 使用搜索框快速查找

### 3. 连接
- 点击主界面的 Connect 按钮
- 等待连接建立
- 查看状态指示器

### 4. 启用 TUN 模式 (可选)
- 进入 Settings 标签页
- 切换 TUN Mode
- 授予管理员权限

## 🛠️ 开发指南

### 环境要求
- **Rust**: >= 1.75.0
- **Flutter**: >= 3.24.0
- **平台支持**:
  - Windows: Visual Studio Build Tools 2022
  - macOS: Xcode Command Line Tools
  - Linux: clang, cmake, ninja-build, libgtk-3-dev
  - Android: Android NDK r25+

### 本地构建

#### Windows
```powershell
# 一键构建
.\build.ps1 -Version dev

# 分步构建
cd rust_core && cargo build --release
cd ..\flutter_ui
flutter pub get
flutter build windows --release
```

#### Linux/macOS
```bash
# 构建 Rust 核心
cd rust_core && cargo build --release

# 构建 Flutter
cd flutter_ui
flutter pub get
flutter build linux --release  # 或 macos
```

### 运行测试
```bash
# Rust 测试
cd rust_core
cargo test

# Flutter 测试
cd flutter_ui
flutter test
```

## 📚 文档

| 文档 | 描述 |
|------|------|
| [QUICK_START_WINDOWS.md](QUICK_START_WINDOWS.md) | Windows 本地构建详细指南 |
| [GITHUB_ACTIONS_GUIDE.md](GITHUB_ACTIONS_GUIDE.md) | GitHub Actions CI/CD 配置 |
| [DESIGN.md](DESIGN.md) | 架构设计文档 |
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | 功能实现说明 |
| [TEST.md](TEST.md) | 测试文档 |

## 📊 项目结构

```
proxy_client/
├── rust_core/              # Rust 核心层
│   ├── src/
│   │   ├── lib.rs         # 主入口
│   │   ├── config/        # 配置管理
│   │   ├── core/          # 核心逻辑
│   │   ├── ipc/           # IPC 通信
│   │   └── kernels/       # 内核适配器
│   └── Cargo.toml
├── flutter_ui/            # Flutter 界面层
│   ├── lib/
│   │   ├── main.dart      # 应用入口
│   │   ├── models/        # 数据模型
│   │   ├── services/      # 业务服务
│   │   └── screens/       # UI 页面
│   ├── test/              # 单元测试
│   └── pubspec.yaml
├── .github/workflows/     # CI/CD 配置
│   ├── windows-build.yml
│   └── multi-platform-build.yml
├── build.ps1              # Windows 构建脚本
└── README.md              # 本文件
```

## 🧪 测试覆盖

### 已实现测试用例
- ✅ Rust 核心：15+ 单元测试
- ✅ Flutter 服务：30+ 单元测试
- ✅ 协议支持：Hysteria2, TUIC, REALITY, WireGuard, SS2022
- ✅ TUN 模式：配置验证测试
- ✅ UI 组件：Widget 测试

### 运行完整测试套件
```bash
# 所有测试
cargo test --manifest-path rust_core/Cargo.toml
flutter test flutter_ui/test/
```

## 🔧 故障排除

### 常见问题

**Q: Windows 上无法启动应用**
```
A: 确保所有 DLL 文件在同一目录
   以管理员身份运行
   检查 Visual C++ Redistributable 是否安装
```

**Q: TUN 模式启用失败**
```
A: 需要管理员权限
   检查防火墙设置
   确认没有其他 VPN 软件冲突
```

**Q: 节点连接超时**
```
A: 验证配置是否正确
   检查网络连接
   尝试其他节点
```

更多问题请参考 [QUICK_START_WINDOWS.md](QUICK_START_WINDOWS.md#故障排除)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## ⚠️ 免责声明

本工具仅供学习和研究使用。请勿用于任何违法用途。使用本工具所产生的一切后果由使用者自行承担。

## 🔗 相关链接

- [sing-box 官方文档](https://sing-box.sagernet.org/)
- [Flutter 官方文档](https://docs.flutter.dev/)
- [Rust 编程语言](https://www.rust-lang.org/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

**Star ⭐ 本项目，获取最新更新通知！**
