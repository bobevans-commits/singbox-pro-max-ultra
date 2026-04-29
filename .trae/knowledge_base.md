# ProxCore 知识库索引

> 更新: 2026-04-28 | 版本: 1.0.0+1 | SDK: ^3.11.5 | 包名: proxcore

## 项目概述

Flutter 多平台代理客户端，支持 sing-box / mihomo / v2ray 三内核，9 种协议。

## 架构

```
main.dart (MultiProvider: KernelManager, ProxyService, SubscriptionService)
├── screens/home_screen.dart    仪表板：状态、流量、网速图、快捷设置、连接信息
├── screens/subscriptions_screen.dart  订阅管理
├── screens/log_screen.dart     日志查看
├── screens/settings_screen.dart 设置页
├── screens/kernel_settings_screen.dart 内核管理
├── screens/node_editor_screen.dart    节点编辑
├── screens/routing_editor_screen.dart 路由规则
├── widgets/proxy_link_importer.dart   链接导入
├── services/proxy_service.dart  核心状态(ChangeNotifier)
├── services/kernel_manager.dart 内核下载/安装/管理(ChangeNotifier)
├── services/subscription_service.dart 订阅刷新/解析(ChangeNotifier)
├── services/config_storage_service.dart SharedPreferences持久化
├── models/config.dart          ProxyConfig/NodeConfig/RoutingRule/DnsConfig
├── models/kernel_info.dart     KernelInfo/KernelReleaseInfo
├── models/singbox_config.dart  sing-box JSON配置模型
├── utils/config_adapter.dart   三内核配置适配生成
└── utils/app_utils.dart        格式化/校验/图标工具
```

## 核心数据模型 (models/config.dart)

### KernelType enum
- `singbox` → label:'sing-box', repo:'SagerNet/sing-box'
- `mihomo` → label:'mihomo', repo:'MetaCubeX/mihomo'
- `v2ray` → label:'v2ray', repo:'XTLS/Xray-core'

### ProxyProtocol enum (9种)
vmess | vless | trojan | shadowsocks | hysteria | hysteria2 | tuic | naive | wireguard

### ProxyConfig
| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| kernelType | KernelType | singbox | 当前内核 |
| localAddress | String | 127.0.0.1 | 监听地址 |
| localPort | int | 1080 | 混合端口(mihomo) |
| socksPort | int | 1080 | SOCKS端口 |
| httpPort | int | 1081 | HTTP端口 |
| tunEnabled | bool | false | TUN模式 |
| systemProxy | bool | false | 系统代理 |
| lanSharing | bool | false | 局域网共享 |
| adBlocking | bool | false | 广告屏蔽 |
| smartNode | bool | false | 智能节点 |
| nodes | List\<NodeConfig\> | [] | 节点列表 |
| dnsConfig | DnsConfig | system | DNS配置 |

### NodeConfig
id, name, protocol, address, port, extra(Map), latencyMs, downloadSpeed

### RoutingRule
id, name, type(domain/domain_keyword/domain_suffix/ip_cidr/geoip/geosite/process/protocol/port), match, target(proxy/direct/block), enabled

### DnsConfig
mode(system/custom/doh/dot), servers, fallbackServers, remoteResolve, dohUrl, dotServer

## 服务层

### ProxyService (核心状态管理器)
- **状态**: ProxyState(stopped/starting/running/stopping)
- **生命周期**: init→loadConfig→start→stop→restart
- **节点管理**: addNode/addNodes/updateNode/deleteNode/clearNodes
- **TUN**: isKernelInstalled() / activeKernelType / kernelManager / toggleTun(bool)
  - toggleTun: 检查内核→更新config→运行中则自动restart
- **测速**: testLatency / testAllLatency / testDownloadSpeed / findBestNode
- **流量**: uploadSpeed/downloadSpeed/uploadBytes/downloadBytes/speedHistory(60条)
- **日志**: logs(≤1000) / logStream / clearLogs
- **配置**: updateConfig→saveProxyConfig→notifyListeners
- **导入导出**: exportConfig / importConfig
- **内核进程**: Process.start(binaryPath, args) → stdout/stderr监听 → exitCode

### KernelManager (内核管理)
- **状态**: KernelStatus(notInstalled/downloading/installing/installed/running/stopping/error)
- **检测**: isInstalled(type) → status==installed||running
- **下载**: downloadKernel(type, version?) → GitHub Releases → .zip/.gz → 解压到assets/bin/
- **进度**: downloadProgress (0.0~1.0)
- **二进制名**: sing-box.exe / mihomo.exe / xray.exe (Windows加.exe)
- **启动参数**: sing-box: `run -c configPath` | mihomo: `-f configPath` | v2ray: `run -c configPath`
- **API**: getLatestVersion / getReleaseList / deleteKernel / getBinaryPath

### SubscriptionService (订阅服务)
- **数据源**: Dio HTTP GET → 解析base64/URI
- **支持协议**: vmess:// vless:// trojan:// ss:// hysteria2:// hy2://
- **操作**: addSubscription / removeSubscription / updateSubscription / refreshSubscription / refreshAll

### ConfigStorageService (持久化)
- **存储**: SharedPreferences (JSON序列化)
- **Keys**: proxy_config / nodes / routing_rules / active_kernel / subscriptions
- **导入导出**: exportConfig(全量JSON) / importConfig(覆盖写入)

## 配置适配器 (utils/config_adapter.dart)

### toSingboxConfig
- inbounds: socks + http + [tun(stack:system, auto_route, strict_route)]
- outbounds: proxy节点 + urltest(auto) + direct + block + dns
- route: rules → final:auto/direct
- experimental: clash_api(9090) + [tun配置]
- DNS: 依赖DnsMode生成servers/fallback/rules/strategy

### toMihomoConfig
- mixed-port / socks-port / port / allow-lan / bind-address / mode:rule
- tun: {enable, stack:system, auto-route, auto-detect-interface}
- proxies: vmess/vless/trojan/ss/hysteria2/others→socks5
- proxy-groups: PROXY(select)
- rules: DOMAIN/DOMAIN-KEYWORD/DOMAIN-SUFFIX/IP-CIDR/GEOIP/GEOSITE/PROCESS-NAME/DST-PORT/MATCH
- dns: fake-ip模式

### toV2rayConfig
- inbounds: socks + http + [tun(dokodemo-door, followRedirect, tproxy:tun)]
- outbounds: proxy + direct + block
- routing: rules(type:field) + domainStrategy:IPIfNonMatch
- dns: servers + queryStrategy:UseIP

### 协议适配 (三内核)
| 协议 | sing-box type | mihomo type | v2ray protocol |
|------|-------------|------------|---------------|
| vmess | vmess | vmess | vmess |
| vless | vless | vless | vless |
| trojan | trojan | trojan | trojan |
| shadowsocks | shadowsocks | ss | shadowsocks |
| hysteria2 | hysteria2 | hysteria2 | socks5(降级) |
| hysteria | hysteria | - | socks5(降级) |
| tuic | tuic | - | socks5(降级) |
| naive | naive | - | socks5(降级) |
| wireguard | wireguard | - | socks5(降级) |

## UI 层

### 主导航 (MainNavigation)
- NavigationBar: 仪表板 / 订阅 / 日志 / 设置
- NavigationDrawer: 节点列表 / 路由规则 / 切换主题 / 关于
- FAB: 添加节点(手动/导入链接/从订阅)
- 节点列表Sheet: 排序(默认/延迟升序/降序/名称) + 筛选(协议) + 分组 + 全部测速

### 仪表板 (HomeScreen)
- _StatusHero: 启停按钮 + 活动节点信息
- _StatChip×2: 上传/下载 速度+总量
- _LatencyChip: 延迟显示(可点击测速)
- _SpeedChart: CustomPaint实时网速曲线(60秒历史)
- _OverviewBar: 节点数/规则数/订阅数/内核
- _QuickSettings: TUN开关(内核检测+安装引导) / 系统代理开关
- _ConnectionGrid: 3×2网格 SOCKS/HTTP/监听/内核/TUN/DNS
- _KernelInstallScreen: 自动下载+进度条+完成后pop(true)

### 设置页 (SettingsScreen)
- 分区卡片: 内核/网络/规则/DNS/端口/数据/外观/关于
- TUN开关: 同样有内核检测+引导安装(导航到KernelSettingsScreen)
- DNS设置: Dialog下拉模式+服务器+备用+DoH/DoT+远程解析
- 端口设置: Dialog监听地址+SOCKS+HTTP
- 数据: 导出(Share)/导入(FilePicker)/清除
- 主题: MyApp.toggleThemeOf

## 依赖 (pubspec.yaml)
- provider ^6.1.2 — 状态管理
- shared_preferences ^2.3.4 — KV持久化
- path_provider ^2.1.5 — 应用目录
- dio ^5.7.0 — HTTP请求
- archive ^4.0.2 — ZIP/GZ解压
- url_launcher ^6.3.1 — 打开链接
- uuid ^4.5.1 — ID生成
- share_plus ^10.1.4 — 分享文件
- file_picker ^8.1.7 — 文件选择

## TUN 模式流程

```
用户点击TUN开关(开启)
  → _onTunToggle()
  → isKernelInstalled()?
    → YES: toggleTun(true) → updateConfig → running?restart
    → NO:  showDialog("需要安装内核")
      → 取消: 结束
      → 前往安装:
        → HomeScreen: Navigator.push(_KernelInstallScreen) → 自动下载 → pop(true) → toggleTun(true)
        → SettingsScreen: Navigator.push(KernelSettingsScreen) → 手动操作
```

## 内核下载流程

```
downloadKernel(type, version?)
  → getLatestVersion(GitHub API) → buildDownloadUrl → HttpClient下载
  → 进度: downloadProgress = receivedBytes/totalBytes → notifyListeners
  → 解压: .zip→ZipDecoder / .gz→GZipDecoder
  → 安装: 写入assets/bin/{binaryName} + chmod +x(非Windows)
  → 状态: notInstalled→downloading→installing→installed
```

## 关键约定

1. **ProxyService是唯一状态源** — UI通过Provider.watch绑定
2. **所有配置变更必须通过updateConfig** — 自动持久化+通知
3. **TUN开启前必须检查内核安装** — toggleTun内部+UI层双重检查
4. **内核二进制存放路径**: assets/bin/ (KernelManager.getKernelDir)
5. **节点去重键**: `address:port:protocol.name`
6. **日志上限**: 1000条 | 速度历史: 60条 | 订阅刷新超时: 30秒
7. **测速方法**: Socket.connect(延迟) / HttpClient下载(速度)
