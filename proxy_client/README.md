# 多平台代理客户端 (Proxy Client)

一套基于 **Rust + Flutter** 的跨平台代理客户端，支持 Windows、macOS、Linux 和 Android。

## 🚀 技术栈

### 核心层 (Rust)
- **语言**: Rust - 高性能、内存安全
- **内核支持**: 
  - ✅ sing-box
  - ✅ mihomo (Clash.Meta)
  - ✅ v2ray-core
- **功能模块**:
  - 配置管理 (JSON/YAML)
  - 内核生命周期管理
  - 系统代理设置
  - IPC 通信 (Unix Socket / Windows Named Pipe)

### 界面层 (Flutter)
- **框架**: Flutter 3.x
- **状态管理**: Provider
- **支持平台**: Windows / macOS / Linux / Android / iOS

## 📁 项目结构

```
proxy_client/
├── rust_core/              # Rust 核心库
│   ├── src/
│   │   ├── lib.rs          # 库入口
│   │   ├── config/         # 配置管理
│   │   ├── core/           # 核心逻辑 (系统代理等)
│   │   ├── kernels/        # 内核适配器
│   │   │   ├── singbox.rs
│   │   │   ├── mihomo.rs
│   │   │   └── v2ray.rs
│   │   └── ipc/            # IPC 通信
│   └── Cargo.toml
├── flutter_ui/             # Flutter 界面
│   ├── lib/
│   │   ├── main.dart       # 应用入口
│   │   ├── models/         # 数据模型
│   │   ├── services/       # 服务层
│   │   ├── screens/        # 页面
│   │   └── widgets/        # 组件
│   ├── test/               # 单元测试
│   └── pubspec.yaml
├── DESIGN.md               # 设计文档
├── TEST.md                 # 测试文档
└── README.md               # 本文件
```

## ✨ 核心特性

1. **多内核支持** - 统一接口适配不同代理内核
2. **热切换** - 无需重启应用即可切换内核
3. **配置导入** - 支持订阅链接、配置文件导入
4. **路由规则** - 自定义分流规则
5. **性能监控** - 实时流量、延迟显示
6. **系统代理** - 自动配置各平台系统代理

## 🔧 开发环境搭建

### Rust 环境

```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 验证安装
rustc --version
cargo --version
```

### Flutter 环境

```bash
# 安装 Flutter SDK
# 参考：https://docs.flutter.dev/get-started/install

# 验证安装
flutter doctor
```

## 🏃 运行与测试

### Rust 核心层

```bash
cd rust_core

# 编译
cargo build --release

# 运行测试
cargo test --lib

# 生成覆盖率报告
cargo tarpaulin --out Html
```

### Flutter 界面层

```bash
cd flutter_ui

# 获取依赖
flutter pub get

# 运行应用 (桌面端)
flutter run -d linux   # 或 windows, macos

# 运行测试
flutter test

# 构建发布版本
flutter build linux    # 或 windows, macos, apk
```

## 📋 单元测试

项目包含完整的单元测试套件，覆盖：

### Rust 测试
- ✅ 配置加载与保存
- ✅ 内核启动/停止逻辑
- ✅ IPC 消息序列化
- ✅ 系统代理设置函数

### Flutter 测试
- ✅ 组件渲染测试
- ✅ 状态管理测试
- ✅ 服务层逻辑测试

详细测试文档见 [TEST.md](TEST.md)

## 🛠️ 构建说明

### Windows

```bash
# Rust DLL
cd rust_core
cargo build --release

# Flutter EXE
cd flutter_ui
flutter build windows
```

### macOS

```bash
# Rust dylib
cd rust_core
cargo build --release

# Flutter App
cd flutter_ui
flutter build macos
```

### Linux

```bash
# Rust so
cd rust_core
cargo build --release

# Flutter Binary
cd flutter_ui
flutter build linux
```

### Android

```bash
# 需要交叉编译 Rust 为 Android 库
# 然后构建 Flutter APK
cd flutter_ui
flutter build apk
```

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## ⚠️ 免责声明

本项目仅供学习交流使用，请勿用于非法用途。
