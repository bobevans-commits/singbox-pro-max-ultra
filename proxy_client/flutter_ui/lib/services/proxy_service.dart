import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/config.dart';

/// 代理服务 - 管理内核生命周期和配置
class ProxyService extends ChangeNotifier {
  KernelStatus _status = KernelStatus.stopped;
  KernelType _currentKernel = KernelType.singBox;
  ProxyConfig? _config;
  String? _errorMessage;
  double _uploadSpeed = 0.0;
  double _downloadSpeed = 0.0;

  KernelStatus get status => _status;
  KernelType get currentKernel => _currentKernel;
  ProxyConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  double get uploadSpeed => _uploadSpeed;
  double get downloadSpeed => _downloadSpeed;
  bool get isRunning => _status == KernelStatus.running;

  /// 启动代理内核
  Future<void> startKernel(KernelType kernel) async {
    try {
      _status = KernelStatus.starting;
      _currentKernel = kernel;
      _errorMessage = null;
      notifyListeners();

      // 调用 Rust 核心层 API (通过 FFI 或 IPC)
      // 这里使用模拟的异步操作
      await Future.delayed(const Duration(seconds: 1));

      _status = KernelStatus.running;
      notifyListeners();
    } catch (e) {
      _status = KernelStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 停止代理内核
  Future<void> stopKernel() async {
    try {
      _status = KernelStatus.stopping;
      notifyListeners();

      // 调用 Rust 核心层 API
      await Future.delayed(const Duration(milliseconds: 500));

      _status = KernelStatus.stopped;
      _uploadSpeed = 0.0;
      _downloadSpeed = 0.0;
      notifyListeners();
    } catch (e) {
      _status = KernelStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 切换内核
  Future<void> switchKernel(KernelType newKernel) async {
    if (_status == KernelStatus.running) {
      await stopKernel();
    }
    await startKernel(newKernel);
  }

  /// 加载配置
  Future<void> loadConfig(String configPath) async {
    try {
      // 从文件加载配置
      // 实际实现中会调用 Rust 核心层
      _config = ProxyConfig(
        kernelType: _currentKernel.name,
        nodes: [
          NodeConfig(
            name: '示例节点',
            type: 'vmess',
            server: 'example.com',
            port: 443,
          ),
        ],
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载配置失败：$e';
      notifyListeners();
      rethrow;
    }
  }

  /// 保存配置
  Future<void> saveConfig(ProxyConfig config, String path) async {
    try {
      // 保存配置到文件
      _config = config;
      notifyListeners();
    } catch (e) {
      _errorMessage = '保存配置失败：$e';
      notifyListeners();
      rethrow;
    }
  }

  /// 启用系统代理
  Future<void> enableSystemProxy() async {
    // 调用 Rust 核心层的系统代理设置
    debugPrint('启用系统代理');
  }

  /// 禁用系统代理
  Future<void> disableSystemProxy() async {
    // 调用 Rust 核心层的系统代理设置
    debugPrint('禁用系统代理');
  }

  /// 更新流量统计
  void updateTraffic(double upload, double download) {
    _uploadSpeed = upload;
    _downloadSpeed = download;
    notifyListeners();
  }

  /// 测试延迟
  Future<int> testLatency(String nodeName) async {
    // 模拟延迟测试
    await Future.delayed(const Duration(milliseconds: 200));
    return (DateTime.now().millisecond % 100) + 50;
  }
}
