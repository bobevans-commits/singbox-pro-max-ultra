# ProxCore - 多内核代理客户端

基于 Flutter 的跨平台代理客户端，支持 sing-box、mihomo (Clash Meta)、v2ray (Xray) 三种内核，覆盖 9 种代理协议。

## 特性

### 内核支持
- **sing-box** - 通用代理平台，支持多种协议和 TUN 模式
- **mihomo** - Clash Meta 内核，兼容 Clash 规则生态
- **v2ray** - Xray 内核，VLESS/XTLS 支持

### 协议支持
VMess | VLESS | Trojan | Shadowsocks | Hysteria | Hysteria2 | TUIC | Naive | WireGuard

### 功能列表
- **内核管理** - 版本选择、下载进度、自动检测更新、一键安装/删除
- **TUN 模式** - 虚拟网卡全局代理，未安装内核时弹窗引导安装
- **系统代理** - 设置系统 HTTP/SOCKS 代理
- **订阅管理** - 导入订阅链接，自动解析节点，刷新后自动导入主列表
- **节点管理** - 手动添加/链接导入/订阅导入，支持排序、筛选、按协议分组
- **路由规则** - 9 种匹配类型，14 条预设规则，拖拽排序，启用/禁用切换
- **DNS 配置** - 系统/自定义/DoH/DoT 四种模式，远程解析支持
- **实时监控** - 上传/下载速度、流量统计、60 秒网速曲线图、延迟测试
- **广告屏蔽** - 基于 GeoSite category-ads-all 规则过滤
- **智能节点** - 自动选择延迟最低的节点
- **局域网共享** - 允许其他设备通过本机代理
- **配置导入导出** - JSON 格式导出/导入，支持文件分享
- **日志查看** - 实时日志流，级别过滤，一键清除
- **主题切换** - 亮色/暗色模式

## 项目结构

```
lib/
├── main.dart                        # 应用入口、导航、节点列表(排序/筛选/分组)
├── models/
│   ├── config.dart                  # ProxyConfig/NodeConfig/RoutingRule/DnsConfig
│   ├── kernel_info.dart             # KernelInfo/KernelReleaseInfo/KernelAssetInfo
│   └── singbox_config.dart          # sing-box JSON 配置模型
├── screens/
│   ├── home_screen.dart             # 仪表板(状态/网速/概要/快捷设置/内核安装引导)
│   ├── kernel_settings_screen.dart  # 内核管理(版本选择/下载进度)
│   ├── log_screen.dart              # 日志查看器
│   ├── node_editor_screen.dart      # 节点编辑器(9种协议)
│   ├── routing_editor_screen.dart   # 路由编辑器(9种匹配/14预设/拖拽排序)
│   ├── settings_screen.dart         # 设置(内核/网络/规则/DNS/端口/数据/外观)
│   └── subscriptions_screen.dart    # 订阅管理(刷新导入/概要统计)
├── services/
│   ├── config_storage_service.dart  # 持久化存储(ProxyConfig/Nodes/Rules/Subs/导入导出)
│   ├── kernel_manager.dart          # 内核管理(下载/安装/版本检测/GitHub API)
│   ├── proxy_service.dart           # 中央状态管理(配置/节点/规则/代理控制/测速)
│   └── subscription_service.dart    # 订阅服务(CRUD/刷新/解析)
├── utils/
│   ├── app_utils.dart               # formatBytes/protocolIcon/latencyColor
│   └── config_adapter.dart          # ProxyConfig → sing-box/mihomo/v2ray JSON
└── widgets/
    └── proxy_link_importer.dart     # 代理链接导入底部弹窗
```

## 架构设计

```
┌─────────────┐     ┌──────────────┐     ┌────────────────────┐
│   UI Layer   │────▶│ ProxyService │────▶│ ConfigStorageService│
│ (screens/)   │◀────│ (中央状态)    │◀────│ (SharedPreferences) │
└─────────────┘     └──────┬───────┘     └────────────────────┘
                           │
                    ┌──────┴───────┐
                    │ KernelManager │
                    │ (内核生命周期) │
                    └──────────────┘
```

- **ProxyService** 作为中央状态管理器，所有页面通过 Provider 统一读写
- 状态变更自动持久化到 ConfigStorageService
- ConfigAdapter 负责将 ProxyConfig 转换为各内核的 JSON 配置格式

## 快速开始

### 环境要求
- Flutter SDK >= 3.11.5
- Dart >= 3.11.5

### 安装与运行
```bash
git clone <repo-url>
cd singbox-pro-max-ultra
flutter pub get
flutter run -d windows
```

### 构建发布版本
```bash
flutter build windows --release   # Windows
flutter build macos --release     # macOS
flutter build linux --release     # Linux
flutter build apk --release       # Android
```

## 使用说明

### 首次使用
1. 启动应用后进入**设置 → 内核管理**
2. 选择需要的内核（推荐 sing-box），点击**安装**
3. 可点击**选择版本**安装指定版本

### TUN 模式
1. 在仪表板或设置页开启 TUN 模式开关
2. 若未安装内核，自动弹窗引导安装
3. 安装完成后自动开启 TUN 并重启代理

### 添加节点
- **手动添加** - 点击 + → 手动添加 → 选择协议 → 填写配置
- **链接导入** - 点击 + → 导入链接 → 粘贴代理链接
- **订阅导入** - 订阅页 → 添加订阅 → 自动解析并导入节点

### 路由规则
1. 侧边栏 → 路由规则
2. 点击预设规则快速添加（国内直连/广告屏蔽/Google等）
3. 支持拖拽排序、启用/禁用、自定义匹配规则

### 配置备份
- **导出** - 设置 → 数据 → 导出配置（JSON 文件分享）
- **导入** - 设置 → 数据 → 导入配置（选择 JSON 文件恢复）

## 开发指南

### 添加新内核
1. `models/config.dart` - 添加 `KernelType` 枚举值
2. `services/kernel_manager.dart` - 添加下载 URL 和二进制名
3. `utils/config_adapter.dart` - 实现 `toXxxConfig()` 转换方法

### 添加新协议
1. `models/config.dart` - 添加 `ProxyProtocol` 枚举值
2. `utils/config_adapter.dart` - 在三个内核的转换方法中添加协议处理
3. `screens/node_editor_screen.dart` - 添加协议编辑表单

### 添加新页面
1. 在 `screens/` 创建页面文件
2. 在 `main.dart` 导航中注册路由
3. 通过 `context.read<ProxyService>()` 访问状态

## 注意事项

- TUN 模式需要管理员/root 权限
- 首次使用需下载内核文件（约 10-30MB）
- 请遵守当地法律法规使用

## 许可证

MIT License
