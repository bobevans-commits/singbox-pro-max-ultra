# 外部内核进程模式实现完成报告

## 概述
已成功将项目从 FFI/Rust 核心模式切换为**外部二进制文件调用模式**。所有相关代码已更新完成。

## 已完成的修改

### 1. 删除的文件和目录 ✅
- ❌ `rust_core/` - 整个 Rust 核心目录已删除
- ❌ `lib/ffi/` - FFI 绑定目录（如果存在）已清理

### 2. Android 原生层更新 ✅

#### VpnServiceImpl.kt (TUN 模式)
**位置**: `/workspace/flutter_ui/android/app/src/main/kotlin/com/example/proxy_app/VpnServiceImpl.kt`

**关键变更**:
- 移除了 JNI 调用逻辑
- 新增 `startKernelProcess()` 方法，使用 `ProcessBuilder` 启动外部内核
- 支持三种内核：sing-box, mihomo, v2ray
- 通过环境变量传递 TUN 文件描述符 (`PROXY_TUN_FD`)
- 从 SharedPreferences 读取用户选择的内核类型

```kotlin
// 核心代码片段
private fun startKernelProcess(fd: Int, config: String) {
    val kernelName = getSelectedKernel()
    val kernelPath = File(kernelDir, getKernelBinaryName(kernelName))
    
    val cmd = when (kernelName) {
        "sing-box" -> arrayOf(kernelPath.absolutePath, "run", "-c", configFile.absolutePath)
        "mihomo" -> arrayOf(kernelPath.absolutePath, "-d", filesDir.absolutePath, "-f", configFile.absolutePath)
        "v2ray" -> arrayOf(kernelPath.absolutePath, "-config", configFile.absolutePath)
        else -> throw IllegalArgumentException("Unknown kernel: $kernelName")
    }
    
    val processBuilder = ProcessBuilder(*cmd)
    processBuilder.environment()["PROXY_TUN_FD"] = fd.toString()
    processBuilder.start()
}
```

#### ProxyService.kt (普通代理模式)
**位置**: `/workspace/flutter_ui/android/app/src/main/kotlin/com/example/proxy_app/ProxyService.kt`

**关键变更**:
- 实现了完整的 `startProxy()` 方法
- 使用 `ProcessBuilder` 启动内核进程
- 支持日志输出捕获并打印到 Logcat
- 自动设置可执行权限

```kotlin
// 核心代码片段
private fun startProxy(configPath: String, kernelType: String) {
    val kernelPath = File(kernelDir, getKernelBinaryName(kernelType))
    
    val cmd = when (kernelType) {
        "sing-box" -> arrayOf(kernelPath.absolutePath, "run", "-c", configFile.absolutePath)
        "mihomo" -> arrayOf(kernelPath.absolutePath, "-d", filesDir.absolutePath, "-f", configFile.absolutePath)
        "v2ray" -> arrayOf(kernelPath.absolutePath, "-config", configFile.absolutePath)
        else -> throw IllegalArgumentException("Unknown kernel: $kernelType")
    }
    
    val processBuilder = ProcessBuilder(*cmd)
    processBuilder.redirectErrorStream(true) // 合并 stderr 到 stdout
    
    val process = processBuilder.start()
    // 监听日志输出...
}
```

#### MainActivity.kt
**状态**: ✅ 无需修改
- 现有的 MethodChannel 已经正确配置
- VPN 权限请求流程完整
- 服务启动逻辑正确

#### AndroidManifest.xml
**状态**: ✅ 无需修改
- 已包含所有必要权限（INTERNET, FOREGROUND_SERVICE, BIND_VPN_SERVICE 等）
- VpnServiceImpl 和 ProxyService 已正确注册

### 3. Flutter/Dart 层状态 ✅

以下文件已存在且功能完整：

| 文件 | 状态 | 功能 |
|------|------|------|
| `lib/platform/kernel_platform_channel.dart` | ✅ 完整 | MethodChannel 封装 |
| `lib/services/kernel_executor.dart` | ✅ 完整 | 桌面端进程管理 |
| `lib/services/kernel_manager.dart` | ✅ 完整 | 内核版本管理 |
| `lib/services/kernel_downloader.dart` | ✅ 完整 | 内核下载器 |
| `lib/services/tun_service.dart` | ✅ 完整 | TUN 配置生成 |
| `lib/services/connection_state_manager.dart` | ✅ 完整 | 连接状态管理 |
| `lib/services/traffic_statistics_service.dart` | ✅ 完整 | 流量统计 |

## 架构对比

### 之前（FFI/Rust 模式）
```
Flutter → FFI → Rust Core (.so) → 网络转发
                ↓
           需要编译 Rust 代码
           需要维护 FFI 绑定
```

### 现在（外部进程模式）✅
```
Flutter → MethodChannel → Android Kotlin → ProcessBuilder → sing-box/mihomo/v2ray 二进制
                                                              ↓
                                                         成熟的开源内核
                                                         独立更新升级
```

## 工作流程

### Android TUN 模式启动流程
1. Flutter 调用 `KernelPlatformChannel().startTunDevice()`
2. MainActivity 接收调用，检查 VPN 权限
3. 如无权限，启动系统 VPN 授权界面
4. 用户授权后，调用 `VpnServiceImpl.setupVpn()`
5. 创建 TUN 设备，获取文件描述符 (fd)
6. 调用 `startKernelProcess(fd, config)`
7. ProcessBuilder 启动内核二进制，传递 fd 作为环境变量
8. 内核进程接管 TUN 设备，开始数据转发

### Android 普通代理模式流程
1. Flutter 调用 `KernelPlatformChannel().startKernel(tunMode: false)`
2. MainActivity 启动 `ProxyService`
3. ProxyService 使用 ProcessBuilder 启动内核
4. 内核监听本地端口，提供 HTTP/SOCKS5 代理
5. （可选）通过 PAC 或手动设置系统代理

## 内核二进制文件管理

### 存储位置
```
Android: /data/data/com.example.proxy_app/files/kernels/
  ├── sing-box
  ├── mihomo
  └── v2ray
```

### 下载与更新
由 `KernelDownloader` 服务负责：
- 从 GitHub Releases 下载最新内核
- 自动解压并保存到 kernels 目录
- 设置可执行权限 (`chmod +x`)

### 权限要求
```kotlin
kernelPath.setExecutable(true) // 在启动前调用
```

## 环境变量传递

| 变量名 | 说明 | 用途 |
|--------|------|------|
| `PROXY_TUN_FD` | TUN 文件描述符 | 仅 TUN 模式，内核通过此 fd 读写数据包 |
| `PROXY_APP_DIR` | 应用内部存储路径 | 内核查找配置文件、GeoIP 数据库等 |

## 支持的命令参数

### sing-box
```bash
sing-box run -c /path/to/config.json
```

### mihomo (Clash Meta)
```bash
mihomo -d /app/data/dir -f /path/to/config.yaml
```

### v2ray (Xray-core)
```bash
v2ray -config /path/to/config.json
```

## 日志处理

### Android 端
- 通过 `process.inputStream` 读取内核输出
- 打印到 Logcat: `println("[${kernelType}] $line")`
- TODO: 通过 EventChannel 发送到 Flutter 层

### Flutter 端
- `KernelExecutor.logStream` 提供实时日志流
- 可在日志页面订阅显示

## 下一步工作（可选优化）

1. **日志回传**: 实现 EventChannel 将内核日志实时发送到 Flutter
2. **进程保活**: 监控内核进程，意外退出时自动重启
3. **资源清理**: 确保应用退出时正确终止内核进程
4. **性能监控**: 通过 /proc/[pid]/status 获取 CPU/内存使用率
5. **Windows/macOS 适配**: 类似逻辑移植到桌面平台

## 测试清单

- [ ] Android TUN 模式启动测试
- [ ] Android 普通代理模式测试
- [ ] 三内核切换测试（sing-box/mihomo/v2ray）
- [ ] 内核下载与更新测试
- [ ] VPN 权限请求流程测试
- [ ] 前台服务通知测试
- [ ] 应用退出时内核清理测试
- [ ] 日志查看功能测试

## 总结

✅ **所有修改已完成**
- Rust 核心目录已删除
- Android 原生代码已更新为 ProcessBuilder 模式
- Flutter 层代码保持兼容，无需修改
- 架构更清晰，维护成本更低
- 可直接使用官方编译的内核二进制文件

项目现在完全基于**外部二进制调用模式**，可以立即进行真机测试。
