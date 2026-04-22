# 多平台代理客户端 - 单元测试套件

## Rust 核心层测试

### 运行 Rust 测试

```bash
cd rust_core
cargo test --lib
```

### 测试覆盖模块

1. **配置管理 (config/mod.rs)**
   - `test_default_config` - 测试默认配置创建
   - `test_save_and_load_config` - 测试配置保存和加载
   - `test_load_nonexistent_file` - 测试加载不存在的文件
   - `test_invalid_json_config` - 测试无效 JSON 配置处理

2. **内核适配器**
   - **singbox.rs**
     - `test_find_binary_not_found` - 测试二进制文件查找
     - `test_is_running_initially_false` - 测试初始状态
   
   - **mihomo.rs**
     - `test_is_running_initially_false` - 测试初始状态
     - `test_find_binary_returns_error_when_not_found` - 测试二进制查找
   
   - **v2ray.rs**
     - `test_is_running_initially_false` - 测试初始状态
     - `test_find_binary_returns_error_when_not_found` - 测试二进制查找

3. **IPC 通信 (ipc/mod.rs)**
   - `test_ipc_message_serialization` - 测试消息序列化
   - `test_ipc_response_serialization` - 测试响应序列化
   - `test_process_message_ping` - 测试 ping 消息处理

4. **核心功能 (lib.rs)**
   - `test_client_creation` - 测试客户端创建
   - `test_kernel_type_serialization` - 测试内核类型序列化

5. **系统代理 (core/system_proxy.rs)**
   - `test_proxy_functions_exist` - 测试代理函数存在性

## Flutter UI 层测试

### 运行 Flutter 测试

```bash
cd flutter_ui
flutter test
```

### 测试覆盖模块

1. **组件测试 (widget_test.dart)**
   - 应用启动测试
   - 主界面显示测试
   - 状态切换测试

2. **服务层测试**
   - ProxyService 状态管理测试
   - 内核切换逻辑测试
   - 配置加载测试

3. **模型测试**
   - KernelType 枚举转换测试
   - KernelStatus 状态描述测试
   - NodeConfig 序列化测试
   - ProxyConfig 序列化测试

## 持续集成 (CI) 配置示例

### GitHub Actions (.github/workflows/test.yml)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  rust-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Rust
        uses: dtolnay/rust-action@stable
      - name: Run Rust tests
        run: |
          cd rust_core
          cargo test --lib

  flutter-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
      - name: Run Flutter tests
        run: |
          cd flutter_ui
          flutter test
```

## 测试报告生成

### Rust 测试覆盖率

```bash
# 安装 cargo-tarpaulin
cargo install cargo-tarpaulin

# 生成覆盖率报告
cd rust_core
cargo tarpaulin --out Html
```

### Flutter 测试覆盖率

```bash
cd flutter_ui
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 手动测试清单

### 功能测试
- [ ] 启动/停止 sing-box 内核
- [ ] 启动/停止 mihomo 内核
- [ ] 启动/停止 v2ray 内核
- [ ] 内核热切换
- [ ] 配置文件导入 (JSON/YAML)
- [ ] 系统代理启用/禁用
- [ ] 节点延迟测试
- [ ] 流量统计显示

### 平台兼容性测试
- [ ] Windows 10/11
- [ ] macOS Intel/Apple Silicon
- [ ] Linux (Ubuntu/Fedora/Arch)
- [ ] Android 10+

### 性能测试
- [ ] 内存占用 < 100MB
- [ ] CPU 占用 < 5% (空闲时)
- [ ] 启动时间 < 3 秒
- [ ] 内核切换时间 < 2 秒
