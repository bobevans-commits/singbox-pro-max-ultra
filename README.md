# Flutter 多内核代理客户端

一个功能完整的 Flutter 代理客户端，支持多种代理协议和多内核切换。

## ✨ 特性

### 核心功能
- 🔄 **多内核支持** - 支持 sing-box、mihomo (Clash Meta)、v2ray (Xray) 三种内核
- 📥 **内核管理** - 自动检测更新、下载、安装、切换和删除内核
- 🌐 **协议支持** - VMess、VLESS、Trojan、Shadowsocks、Hysteria、Hysteria2、TUIC 等
- 📝 **订阅管理** - 支持导入和管理多个订阅链接
- 🔧 **节点编辑** - 可视化编辑各种协议的详细配置
- 🛣️ **路由规则** - 自定义路由规则，支持域名/IP/协议/端口等多种匹配方式
- 📊 **实时监控** - 流量统计、延迟测试、连接状态监控
- 📋 **日志查看** - 实时日志流，支持级别过滤和导出

### 技术特性
- 🎨 **Material 3** - 现代化 UI 设计，支持亮色/暗色主题
- 📱 **多平台** - 支持 Windows、macOS、Linux、Android
- 💾 **本地存储** - 配置持久化，支持导入导出
- 🔌 **插件架构** - 模块化设计，易于扩展

## 🏗️ 项目结构

```
lib/
├── main.dart                 # 应用入口和主导航
├── models/                   # 数据模型
│   ├── config.dart          # 内核类型和配置模型
│   ├── kernel_info.dart     # 内核信息模型
│   └── singbox_config.dart  # sing-box 配置模型
├── screens/                  # 页面
│   ├── home_screen.dart     # 仪表板
│   ├── subscriptions_screen.dart  # 订阅管理
│   ├── node_editor_screen.dart    # 节点编辑器
│   ├── routing_editor_screen.dart # 路由编辑器
│   ├── log_screen.dart      # 日志查看器
│   └── kernel_settings_screen.dart # 内核管理
├── services/                 # 服务层
│   ├── proxy_service.dart   # 代理服务
│   ├── kernel_manager.dart  # 内核管理器（下载/更新/切换）
│   ├── kernel_executor.dart # 内核执行器（进程管理）
│   ├── config_storage_service.dart  # 配置存储
│   └── subscription_service.dart    # 订阅服务
├── utils/                    # 工具类
│   ├── app_utils.dart       # 通用工具函数
│   └── config_adapter.dart  # 配置格式适配器
└── widgets/                  # 可复用组件
    └── proxy_link_importer.dart  # 代理链接导入器
```

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0

### 安装依赖
```bash
cd flutter_ui
flutter pub get
```

### 运行应用
```bash
flutter run
```

### 构建发布版本
```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Android
flutter build apk --release
```

## 📖 使用说明

### 内核管理
1. 进入"Kernel"标签页
2. 选择需要的内核类型（sing-box/mihomo/v2ray）
3. 点击"下载"按钮下载安装包
4. 下载完成后可通过菜单切换或删除内核

### 添加节点
1. 在首页点击"+"按钮
2. 选择手动添加或批量导入
3. 填写节点配置信息
4. 保存后即可使用

### 订阅管理
1. 进入"Subscriptions"标签页
2. 添加订阅链接
3. 设置自动更新间隔
4. 点击刷新按钮更新节点

## 🔧 开发指南

### 添加新内核支持
1. 在 `models/config.dart` 中添加新的 `KernelType`
2. 在 `services/kernel_manager.dart` 中实现下载逻辑
3. 在 `utils/config_adapter.dart` 中实现配置转换

### 添加新协议支持
1. 在 `config_adapter.dart` 中添加协议转换逻辑
2. 在 `node_editor_screen.dart` 中添加编辑界面

## 📝 注意事项

- 首次使用需要下载对应的内核文件
- 某些功能可能需要管理员权限（如 TUN 模式）
- 请遵守当地法律法规使用

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License
