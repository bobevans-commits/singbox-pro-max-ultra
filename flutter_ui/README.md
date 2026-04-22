# Proxy Client - Flutter 代理应用

一个基于 Flutter 的多平台代理客户端，支持 sing-box、mihomo (Clash)、v2ray-core 等核心。

## 功能特性

### 已完成功能

1. **仪表板 (Dashboard)**
   - 实时状态显示（运行/停止）
   - 上传/下载流量统计
   - 延迟测试
   - TUN 模式切换
   - 快速操作按钮

2. **节点管理**
   - 支持多种协议：VMess、VLESS、Trojan、Shadowsocks、Hysteria/Hysteria2、TUIC
   - 节点导入（支持分享链接批量导入）
   - 节点编辑（完整配置界面）
   - 节点删除
   - 节点详情查看

3. **订阅管理**
   - 添加/编辑/删除订阅
   - 订阅更新
   - 自动解析多种协议链接

4. **路由规则**
   - 可视化规则创建/编辑
   - 支持域名、IP、协议、端口等多种规则类型
   - 常用预设规则快速添加
   - 规则排序和删除

5. **DNS 配置**
   - DNS 服务器管理
   - DNS 规则配置
   - 最终 DNS 设置

6. **日志查看器**
   - 实时日志显示
   - 级别过滤（全部/错误/警告/信息/调试）
   - 自动滚动
   - 日志导出和清空

7. **设置**
   - TUN 模式开关
   - 开机启动选项
   - 配置导入/导出
   - 开发者选项

### 新增功能（本次完善）

8. **代理链接导入器** (`widgets/proxy_link_importer.dart`)
   - 支持批量导入 vmess://, vless://, trojan://, ss://, hysteria://, hysteria2://, tuic:// 链接
   - 实时解析预览
   - 错误提示
   - 一键导入所有有效节点

9. **工具类** (`utils/app_utils.dart`)
   - 网络连通性测试
   - 代理链接解析（所有主流协议）
   - 字节格式化
   - IP/CIDR 和域名验证

## 项目结构

```
lib/
├── main.dart                     # 应用入口和主导航
├── models/
│   ├── config.dart               # 通用配置模型
│   └── singbox_config.dart       # sing-box 配置模型（完整）
├── screens/
│   ├── home_screen.dart          # 主屏幕（包含 5 个标签页）
│   ├── subscriptions_screen.dart # 订阅管理
│   ├── node_editor_screen.dart   # 节点编辑器
│   ├── routing_editor_screen.dart # 路由规则编辑器
│   └── log_screen.dart           # 日志查看器
├── services/
│   ├── proxy_service.dart        # 代理服务（核心逻辑）
│   ├── subscription_service.dart # 订阅服务
│   └── config_storage_service.dart # 配置存储服务
├── utils/
│   └── app_utils.dart            # 工具函数（新增）
└── widgets/
    └── proxy_link_importer.dart  # 代理链接导入器（新增）
```

## 支持的协议

- ✅ VMess (含 WebSocket/gRPC/HTTP 传输)
- ✅ VLESS (含 Reality、XTLS)
- ✅ Trojan
- ✅ Shadowsocks
- ✅ Hysteria / Hysteria2
- ✅ TUIC
- ✅ WireGuard (配置支持)

## 下一步计划

1. **实际内核集成**
   - 集成 sing-box Rust 核心（通过 FFI 或 IPC）
   - 实现真实的代理连接功能
   - 添加平台特定的权限处理

2. **增强功能**
   - 节点分组管理
   - 延迟测试自动化
   - 流量统计图表
   - 规则集管理（GeoSite/GeoIP）
   - 多语言支持（i18n）
   - 主题自定义

3. **平台特定功能**
   - Windows: 系统托盘、开机自启
   - macOS: 系统扩展、菜单栏
   - Linux: 系统托盘、Desktop 文件
   - Android: VPN Service、后台保活

## 开发说明

### 环境要求
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0

### 构建命令
```bash
# 获取依赖
flutter pub get

# 运行应用
flutter run

# 构建发布版本
flutter build windows  # Windows
flutter build macos    # macOS
flutter build linux    # Linux
flutter build apk      # Android
```

### 代码规范
- 使用 Dart 官方格式化工具
- 遵循 Effective Dart 指南
- 所有公共 API 必须有文档注释

## 许可证

MIT License
