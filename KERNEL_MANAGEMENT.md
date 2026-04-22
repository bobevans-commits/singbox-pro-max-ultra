# Flutter 代理应用 - 内核管理功能完善

## 本次更新内容

### 1. 新增内核下载器服务 (`kernel_downloader.dart`)
- 支持 sing-box、mihomo (Clash Meta)、v2ray (Xray) 三种内核的下载
- 实现断点续传和下载进度实时显示
- 自动解压 tar.gz、gz、zip 等格式的内核包
- 跨平台支持：Windows/macOS/Linux/Android
- 取消令牌支持，可随时中断下载

### 2. 新增内核配置生成器 (`kernel_config_generator.dart`)
- 将通用配置转换为不同内核所需的格式
- **sing-box 格式**: JSON 配置文件，支持 VMess/VLESS/Trojan/Shadowsocks/Hysteria/TUIC
- **mihomo 格式**: YAML 配置文件，兼容 Clash Meta 语法
- **v2ray 格式**: JSON 配置文件，支持 Xray-core
- 自动处理节点转换、路由规则、DNS 配置

### 3. 更新依赖
- 添加 `archive: ^3.4.0` 用于解压内核文件

### 4. UI 优化
- 内核设置页面增加下载状态显示
- 改进下载进度提示
- 优化版本列表展示

## 项目结构

```
lib/
├── models/
│   ├── config.dart           # 配置模型（KernelType, ProxyConfig 等）
│   └── kernel_info.dart      # 内核信息模型（KernelInfo, KernelRelease, DownloadProgress）
├── services/
│   ├── kernel_manager.dart        # 内核管理器（核心服务）
│   ├── kernel_downloader.dart     # 内核下载器（新增）
│   ├── kernel_executor.dart       # 内核执行器
│   ├── kernel_config_generator.dart # 配置生成器（新增）
│   ├── proxy_service.dart         # 代理服务
│   └── config_storage_service.dart # 配置存储
├── screens/
│   ├── kernel_settings_screen.dart # 内核管理界面
│   ├── home_screen.dart           # 主界面
│   └── ...
├── utils/
│   ├── config_adapter.dart        # 配置适配器
│   └── app_utils.dart             # 工具函数
└── widgets/
    └── proxy_link_importer.dart   # 代理链接导入器
```

## 核心功能

### 内核类型支持
| 内核 | 仓库 | 协议支持 |
|------|------|----------|
| sing-box | SagerNet/sing-box | VMess, VLESS, Trojan, Shadowsocks, Hysteria, Hysteria2, TUIC, WireGuard |
| mihomo | MetaCubeX/mihomo | VMess, VLESS, Trojan, Shadowsocks, Snell, Hysteria, Hysteria2, TUIC |
| v2ray | XTLS/Xray-core | VMess, VLESS, Trojan, Shadowsocks, Dokodemo, Freedom, Blackhole |

### 下载流程
1. 用户在内核管理页面选择要下载的内核类型
2. 从 GitHub Releases 获取最新版本列表
3. 根据平台和架构选择合适的下载链接
4. 显示实时下载进度和速度
5. 自动解压并设置可执行权限
6. 更新内核信息并通知 UI

### 配置生成流程
1. 用户选择要使用的内核类型
2. 从存储中加载通用配置（节点、路由、DNS 等）
3. 根据内核类型调用相应的适配器
4. 生成符合该内核格式要求的配置文件
5. 返回配置文件路径供内核启动使用

## 使用示例

### 下载内核
```dart
final manager = KernelManager();
await manager.initialize();

// 下载最新版本的 sing-box
final success = await manager.downloadKernel(
  type: KernelType.singBox,
);

// 或者下载指定版本
await manager.downloadKernel(
  type: KernelType.mihomo,
  version: '1.18.0',
);
```

### 切换内核
```dart
// 切换到 mihomo 内核
await manager.switchKernel(KernelType.mihomo);

// 检查当前内核是否就绪
if (manager.isCurrentKernelReady) {
  print('当前内核：${manager.selectedKernelType.name}');
  print('版本：${manager.selectedKernel?.version}');
}
```

### 生成配置文件
```dart
final configPath = await KernelConfigGenerator.generateConfig(
  kernelType: KernelType.singBox,
  baseConfig: {
    'http_port': 7890,
    'socks_port': 7891,
    'log_level': 'info',
    'nodes': [
      {
        'name': 'My Proxy',
        'type': 'vmess',
        'server': 'example.com',
        'port': 443,
        'uuid': 'xxx-xxx-xxx',
      },
    ],
  },
);
```

## 下一步计划

1. **实际内核集成**
   - 实现 Platform Channel 调用底层内核
   - 添加系统代理设置
   - 实现 TUN 模式支持

2. **性能优化**
   - 添加下载缓存机制
   - 优化大文件解压性能
   - 实现增量更新

3. **用户体验**
   - 添加内核启动日志查看
   - 实现连接速度测试
   - 添加流量统计

4. **安全增强**
   - 配置文件加密存储
   - 订阅链接加密传输
   - 添加隐私保护选项

## 开发说明

### 添加新内核支持
1. 在 `config.dart` 中添加新的 `KernelType` 枚举值
2. 在 `kernel_manager.dart` 中更新 `_getGithubRepoUrl()` 方法
3. 在 `kernel_downloader.dart` 中更新 `_getDownloadUrl()` 方法
4. 在 `kernel_config_generator.dart` 中添加配置适配逻辑
5. 更新 UI 中的图标和显示文本

### 调试技巧
- 启用详细日志：设置 `log_level` 为 `debug`
- 查看下载进度：监听 `KernelDownloader().progressStream`
- 测试配置生成：使用 `KernelConfigGenerator.generateConfig()` 并检查输出文件

## 注意事项

1. **网络要求**: 下载内核需要访问 GitHub，可能需要代理环境
2. **存储空间**: 每个内核约 10-30MB，请确保有足够存储空间
3. **权限问题**: Linux/macOS 需要可执行权限，已自动设置
4. **平台兼容性**: Windows 使用 `.exe` 文件，其他平台使用无扩展名二进制文件
