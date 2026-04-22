# 多平台代理客户端设计方案

## 技术栈选择

### 核心层 (Rust)
- **语言**: Rust - 高性能、内存安全、跨平台编译
- **内核集成**: 
  - sing-box: 通过 FFI 或独立进程调用
  - mihomo: 通过 FFI 或独立进程调用  
  - v2ray-core: 通过 FFI 或独立进程调用
- **功能模块**:
  - 配置管理 (JSON/YAML 解析)
  - 内核生命周期管理 (启动/停止/重启)
  - 系统代理设置
  - 日志收集
  - 性能监控

### 界面层 (Flutter)
- **框架**: Flutter - 一套代码支持 Windows/macOS/Linux/Android/iOS
- **状态管理**: Provider/Riverpod
- **UI 组件**: Material Design + 自定义主题
- **通信**: Platform Channels (与 Rust 核心通信)

### 通信协议
- **本地通信**: Unix Domain Socket (Linux/macOS) / Named Pipe (Windows)
- **消息格式**: JSON-RPC 2.0
- **数据序列化**: serde_json

## 项目结构

```
proxy_client/
├── rust_core/          # Rust 核心库
│   ├── src/
│   │   ├── lib.rs      # 库入口
│   │   ├── core/       # 核心逻辑
│   │   ├── kernels/    # 各内核适配器
│   │   ├── config/     # 配置管理
│   │   └── ipc/        # IPC 通信
│   └── Cargo.toml
├── flutter_ui/         # Flutter 界面
│   ├── lib/
│   │   ├── main.dart   # 应用入口
│   │   ├── screens/    # 页面
│   │   ├── widgets/    # 组件
│   │   └── services/   # 服务层
│   ├── test/           # 单元测试
│   └── pubspec.yaml
└── DESIGN.md           # 设计文档
```

## 核心特性

1. **多内核支持**: 统一接口适配不同代理内核
2. **热切换**: 无需重启应用即可切换内核
3. **配置导入**: 支持订阅链接、配置文件导入
4. **路由规则**: 自定义分流规则
5. **性能监控**: 实时流量、延迟显示
6. **系统代理**: 自动配置系统代理设置

## 构建流程

1. Rust 核心编译为动态库 (.dll/.so/.dylib)
2. Flutter 通过 FFI 调用 Rust 函数
3. 各平台打包工具生成安装包
