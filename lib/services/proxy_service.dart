// ProxCore 核心代理服务
// 管理代理内核的完整生命周期：启动、停止、重启、崩溃自启
// 同时负责节点管理、流量统计、系统代理、TUN模式、智能选路等核心功能

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/config.dart';
import '../utils/config_adapter.dart';
import 'clash_api_service.dart';
import 'config_storage_service.dart';
import 'kernel_manager.dart';
import 'smart_router.dart';
import 'system_proxy_service.dart';

/// 代理运行状态
enum ProxyState { stopped, starting, running, stopping }

/// 核心代理服务 — 全局唯一状态源
///
/// 职责：
/// - 代理内核进程的启停与崩溃自启（最多3次）
/// - 节点增删改查与去重（address:port:protocol）
/// - 实时流量统计与速度历史（60秒窗口）
/// - 系统代理设置/移除（Windows注册表/macOS networksetup）
/// - TUN模式切换（需内核已安装）
/// - 智能节点选择（自动测速→选最低延迟）
/// - 配置持久化（通过 ConfigStorageService）
/// - ClashApi WebSocket 实时通信
/// - SmartRouter 历史评分记录
class ProxyService extends ChangeNotifier {
  final KernelManager _kernelManager;
  final ConfigStorageService _storage;

  /// Clash API 服务，用于实时流量/日志/节点状态监听
  ClashApiService? _clashApi;

  /// AI 智能路由，基于历史速度和稳定性评分
  SmartRouter? _smartRouter;

  ProxyState _state = ProxyState.stopped;
  ProxyConfig _config = ProxyConfig();
  NodeConfig? _activeNode;
  Process? _process;

  /// 代理启动时间，用于计算运行时长
  DateTime? _startedAt;

  /// 崩溃计数器，用于自动重启逻辑
  int _crashCount = 0;

  /// 最大自动重启次数，超过后不再重试
  static const int _maxCrashAutoRestart = 3;

  int _uploadBytes = 0;
  int _downloadBytes = 0;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  int _lastUploadBytes = 0;
  int _lastDownloadBytes = 0;

  /// 日志列表，最多保留1000条
  final List<String> _logs = [];

  /// 日志广播流，供UI实时监听
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  /// 当前活动节点延迟（毫秒），-1表示不可达
  int? _latencyMs;

  List<RoutingRule> _routingRules = [];
  List<NodeConfig> _nodes = [];

  /// 每秒速度更新定时器
  Timer? _speedTimer;

  /// 速度历史记录，保留最近60秒
  final List<SpeedRecord> _speedHistory = [];

  // ---- 公开 Getter ----

  ProxyState get state => _state;
  ProxyConfig get config => _config;
  NodeConfig? get activeNode => _activeNode;
  bool get isRunning => _state == ProxyState.running;
  DateTime? get startedAt => _startedAt;

  /// 运行时长，未运行时返回null
  Duration? get uptime =>
      _startedAt != null ? DateTime.now().difference(_startedAt!) : null;

  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  List<String> get logs => List.unmodifiable(_logs);
  Stream<String> get logStream => _logController.stream;
  int? get latencyMs => _latencyMs;
  List<RoutingRule> get routingRules => List.unmodifiable(_routingRules);
  List<NodeConfig> get nodes => List.unmodifiable(_nodes);
  List<SpeedRecord> get speedHistory => List.unmodifiable(_speedHistory);

  ProxyService(this._kernelManager, this._storage) {
    // 每秒更新速度统计和速度历史
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateSpeed();
    });
  }

  /// 从持久化存储加载配置、节点和路由规则
  Future<void> init() async {
    _config = _storage.loadProxyConfig();
    _nodes = _storage.loadNodes();
    _routingRules = _storage.loadRoutingRules();
    notifyListeners();
  }

  /// 注入 ClashApi 服务实例
  void setClashApi(ClashApiService api) => _clashApi = api;

  /// 注入 SmartRouter 服务实例
  void setSmartRouter(SmartRouter router) => _smartRouter = router;

  /// 每秒更新速度统计
  ///
  /// 计算方式：当前累计字节 - 上次累计字节 = 每秒速度
  /// 同时将速度记录追加到历史列表（保留60秒）
  void _updateSpeed() {
    _uploadSpeed = _uploadBytes - _lastUploadBytes;
    _downloadSpeed = _downloadBytes - _lastDownloadBytes;
    _lastUploadBytes = _uploadBytes;
    _lastDownloadBytes = _downloadBytes;

    if (isRunning) {
      _speedHistory.add(
        SpeedRecord(
          time: DateTime.now(),
          upload: _uploadSpeed,
          download: _downloadSpeed,
        ),
      );
      if (_speedHistory.length > 60) {
        _speedHistory.removeRange(0, _speedHistory.length - 60);
      }
    }

    notifyListeners();
  }

  // ---- 配置管理 ----

  /// 更新代理配置并自动持久化
  void updateConfig(ProxyConfig config) {
    _config = config;
    _storage.saveProxyConfig(config);
    notifyListeners();
  }

  /// 检查当前选择的内核是否已安装
  bool isKernelInstalled() {
    return _kernelManager.isInstalled(_config.kernelType);
  }

  /// 当前活跃的内核类型
  KernelType get activeKernelType => _config.kernelType;

  /// 获取内核管理器实例
  KernelManager get kernelManager => _kernelManager;

  /// 切换 TUN 模式
  ///
  /// 开启前检查内核是否已安装，未安装则不执行
  /// 如果代理正在运行，切换后自动重启以应用新配置
  Future<void> toggleTun(bool enable) async {
    if (enable && !isKernelInstalled()) {
      return;
    }

    final wasRunning = isRunning;
    final currentNode = _activeNode;

    updateConfig(_config.copyWith(tunEnabled: enable));

    if (wasRunning && currentNode != null) {
      await restart(currentNode);
    }
  }

  // ---- 节点管理 ----

  /// 添加单个节点
  void addNode(NodeConfig node) {
    _nodes.add(node);
    _storage.saveNodes(_nodes);
    notifyListeners();
  }

  /// 批量添加节点（自动去重，去重键: address:port:protocol）
  void addNodes(List<NodeConfig> newNodes) {
    final existingIds = _nodes
        .map((n) => '${n.address}:${n.port}:${n.protocol.name}')
        .toSet();
    for (final node in newNodes) {
      final key = '${node.address}:${node.port}:${node.protocol.name}';
      if (!existingIds.contains(key)) {
        _nodes.add(node);
        existingIds.add(key);
      }
    }
    _storage.saveNodes(_nodes);
    notifyListeners();
  }

  /// 更新指定节点
  void updateNode(NodeConfig node) {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index >= 0) {
      _nodes[index] = node;
      _storage.saveNodes(_nodes);
      notifyListeners();
    }
  }

  /// 删除指定ID的节点
  void deleteNode(String id) {
    _nodes.removeWhere((n) => n.id == id);
    _storage.saveNodes(_nodes);
    notifyListeners();
  }

  /// 清空所有节点
  void clearNodes() {
    _nodes.clear();
    _storage.saveNodes(_nodes);
    notifyListeners();
  }

  // ---- 路由规则管理 ----

  /// 批量更新路由规则
  void updateRoutingRules(List<RoutingRule> rules) {
    _routingRules = rules;
    _storage.saveRoutingRules(rules);
    notifyListeners();
  }

  /// 添加单条路由规则
  void addRoutingRule(RoutingRule rule) {
    _routingRules.add(rule);
    _storage.saveRoutingRules(_routingRules);
    notifyListeners();
  }

  /// 删除指定ID的路由规则
  void deleteRoutingRule(String id) {
    _routingRules.removeWhere((r) => r.id == id);
    _storage.saveRoutingRules(_routingRules);
    notifyListeners();
  }

  // ---- 导入/导出 ----

  /// 导出全量配置为JSON字符串
  Future<String> exportConfig() async {
    return _storage.exportConfig();
  }

  /// 从JSON字符串导入配置，成功后重新加载
  Future<bool> importConfig(String jsonStr) async {
    final result = await _storage.importConfig(jsonStr);
    if (result) {
      await init();
    }
    return result;
  }

  // ---- 智能节点 ----

  /// 智能选择最优节点
  ///
  /// 1. 对未测速的节点执行延迟测试
  /// 2. 调用 findBestNode 选择最低延迟节点
  Future<NodeConfig?> _pickSmartNode() async {
    if (_nodes.isEmpty) return null;

    final untested = _nodes.where((n) => n.latencyMs == null).toList();
    if (untested.isNotEmpty) {
      await testAllLatency(untested);
    }

    return findBestNode(_nodes);
  }

  // ---- 代理控制 ----

  /// 启动代理
  ///
  /// 流程：
  /// 1. 若开启智能节点，自动选择最优节点
  /// 2. 获取内核二进制路径
  /// 3. 生成内核配置文件（JSON）
  /// 4. Process.start 启动内核进程
  /// 5. 监听 stdout/stderr 输出
  /// 6. 等待2秒确认进程未立即退出
  /// 7. 成功后：连接 ClashApi、记录 SmartRouter、设置系统代理
  /// 8. 进程崩溃时：自动清理系统代理，尝试重启（最多3次）
  Future<void> start(NodeConfig node) async {
    if (_state == ProxyState.running || _state == ProxyState.starting) return;

    // 智能节点模式：自动选择最优节点
    if (_config.smartNode) {
      final best = await _pickSmartNode();
      if (best != null) {
        node = best;
        _addLog('[ProxyService] Smart node selected: ${node.name}');
      }
    }

    _activeNode = node;
    _state = ProxyState.starting;
    _startedAt = null;
    _uploadBytes = 0;
    _downloadBytes = 0;
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _lastUploadBytes = 0;
    _lastDownloadBytes = 0;
    _latencyMs = null;
    _speedHistory.clear();
    notifyListeners();

    _addLog('[ProxyService] Starting proxy with ${node.name}...');

    try {
      final binaryPath = await _getKernelBinaryPath();
      final configPath = await _writeKernelConfig(node);
      final args = _buildKernelArgs(configPath);

      _process = await Process.start(binaryPath, args);

      // 监听标准输出，解析流量数据
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _addLog(line);
            _parseTrafficLine(line);
          });

      // 监听错误输出
      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _addLog('[ERROR] $line');
          });

      // 进程退出回调 — 处理崩溃自启和资源清理
      _process!.exitCode.then((code) async {
        _addLog('[ProxyService] Process exited with code $code');
        if (_state == ProxyState.starting || _state == ProxyState.running) {
          // 清理系统代理
          if (_config.systemProxy) {
            await _removeSystemProxy();
          }
          // 记录连接失败到 SmartRouter
          if (_activeNode != null) {
            _smartRouter?.recordConnect(_activeNode!, success: false);
          }
          // 断开 ClashApi WebSocket
          _clashApi?.disconnect();

          // 崩溃自启逻辑：最多重试 _maxCrashAutoRestart 次
          if (_crashCount < _maxCrashAutoRestart && _activeNode != null) {
            _crashCount++;
            _addLog(
              '[ProxyService] Auto-restart attempt $_crashCount/$_maxCrashAutoRestart',
            );
            await Future.delayed(const Duration(seconds: 2));
            if (_state == ProxyState.stopped && _activeNode != null) {
              await start(_activeNode!);
              return;
            }
          }

          _state = ProxyState.stopped;
          _activeNode = null;
          _startedAt = null;
          notifyListeners();
        }
      });

      // 等待2秒确认进程未立即退出（exitCode=-1 表示超时，即进程仍在运行）
      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );

      if (exitCode == -1) {
        // 进程仍在运行，启动成功
        _state = ProxyState.running;
        _startedAt = DateTime.now();
        _crashCount = 0;
        _addLog('[ProxyService] Proxy started successfully');
        testLatency(node);
        // 设置系统代理
        if (_config.systemProxy) {
          await _applySystemProxy();
        }
        // 连接 ClashApi WebSocket 实时流量监听
        _clashApi?.configure(apiUrl: 'http://127.0.0.1:9090');
        _clashApi?.connect();
        // 记录连接成功到 SmartRouter
        _smartRouter?.recordConnect(node, success: true);
      } else {
        // 进程立即退出，启动失败
        _addLog(
          '[ProxyService] Process exited immediately with code $exitCode',
        );
        _state = ProxyState.stopped;
        _activeNode = null;
      }
    } catch (e) {
      _addLog('[ProxyService] Failed to start: $e');
      _state = ProxyState.stopped;
      _activeNode = null;
    }

    notifyListeners();
  }

  /// 停止代理
  ///
  /// 流程：
  /// 1. 设置崩溃计数器为最大值，阻止崩溃自启
  /// 2. 断开 ClashApi
  /// 3. 终止内核进程（先 SIGTERM，5秒后 SIGKILL）
  /// 4. 清理系统代理
  Future<void> stop() async {
    if (_state != ProxyState.running && _state != ProxyState.starting) return;

    _state = ProxyState.stopping;
    _crashCount = _maxCrashAutoRestart; // 阻止崩溃自启
    _addLog('[ProxyService] Stopping proxy...');
    notifyListeners();

    _clashApi?.disconnect();

    try {
      _process?.kill();
      await _process?.exitCode.timeout(const Duration(seconds: 5));
    } catch (e) {
      _addLog('[ProxyService] Force killing process...');
      _process?.kill(ProcessSignal.sigkill);
    }

    _process = null;
    _state = ProxyState.stopped;
    _activeNode = null;
    _startedAt = null;
    _uploadSpeed = 0;
    _downloadSpeed = 0;

    // 清理系统代理
    if (_config.systemProxy) {
      await _removeSystemProxy();
    }

    _addLog('[ProxyService] Proxy stopped');
    notifyListeners();
  }

  /// 重启代理（先停后启）
  Future<void> restart(NodeConfig node) async {
    await stop();
    await start(node);
  }

  /// 测试单个节点延迟（TCP连接耗时）
  Future<int> testLatency(NodeConfig node) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        node.address,
        node.port,
        timeout: const Duration(seconds: 5),
      );
      stopwatch.stop();
      socket.destroy();
      _latencyMs = stopwatch.elapsedMilliseconds;
    } catch (_) {
      stopwatch.stop();
      _latencyMs = -1; // -1 表示不可达
    }
    notifyListeners();
    return _latencyMs!;
  }

  /// 批量测试节点延迟（并发执行）
  Future<void> testAllLatency(List<NodeConfig> nodes) async {
    final futures = nodes.map((node) async {
      final stopwatch = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          node.address,
          node.port,
          timeout: const Duration(seconds: 5),
        );
        stopwatch.stop();
        socket.destroy();
        node.latencyMs = stopwatch.elapsedMilliseconds;
      } catch (_) {
        stopwatch.stop();
        node.latencyMs = -1;
      }
    });
    await Future.wait(futures);
    notifyListeners();
  }

  /// 测试节点下载速度（从 cachefly 下载1MB文件）
  Future<double> testDownloadSpeed(NodeConfig node) async {
    try {
      final stopwatch = Stopwatch()..start();
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('https://cachefly.cachefly.net/1mb.test'),
      );
      final response = await request.close();

      int totalBytes = 0;
      await for (final chunk in response) {
        totalBytes += chunk.length;
      }
      stopwatch.stop();

      client.close();

      if (stopwatch.elapsedMilliseconds > 0) {
        final speed = (totalBytes * 1000) / stopwatch.elapsedMilliseconds;
        node.downloadSpeed = speed;
        notifyListeners();
        return speed;
      }
    } catch (e) {
      node.downloadSpeed = -1;
      notifyListeners();
    }
    return -1;
  }

  /// 从节点列表中找到延迟最低的节点
  NodeConfig? findBestNode(List<NodeConfig> nodes) {
    final tested = nodes.where((n) => n.latencyMs != null && n.latencyMs! > 0);
    if (tested.isEmpty) return null;
    return tested.reduce(
      (a, b) => (a.latencyMs ?? 9999) < (b.latencyMs ?? 9999) ? a : b,
    );
  }

  /// 获取当前内核的二进制文件路径
  Future<String> _getKernelBinaryPath() async {
    return _kernelManager.getBinaryPath(_config.kernelType);
  }

  /// 根据内核类型构建启动参数
  List<String> _buildKernelArgs(String configPath) {
    switch (_config.kernelType) {
      case KernelType.singbox:
        return ['run', '-c', configPath];
      case KernelType.mihomo:
        return ['-f', configPath];
      case KernelType.v2ray:
        return ['run', '-c', configPath];
    }
  }

  /// 生成内核配置文件到临时目录
  ///
  /// 根据当前内核类型调用对应的 ConfigAdapter 方法
  /// 生成 JSON 格式配置并写入临时文件
  Future<String> _writeKernelConfig(NodeConfig node) async {
    final dir = Directory.systemTemp.createTempSync('singbox_config_');
    final file = File('${dir.path}/config.json');

    Map<String, dynamic> configJson;
    switch (_config.kernelType) {
      case KernelType.singbox:
        configJson = ConfigAdapter.toSingboxConfig(
          _config,
          node,
          _routingRules,
        );
      case KernelType.mihomo:
        configJson = ConfigAdapter.toMihomoConfig(_config, node, _routingRules);
      case KernelType.v2ray:
        configJson = ConfigAdapter.toV2rayConfig(_config, node, _routingRules);
    }

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(configJson),
    );
    return file.path;
  }

  /// 解析内核输出的流量数据行（JSON格式）
  void _parseTrafficLine(String line) {
    try {
      if (line.trim().startsWith('{')) {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json.containsKey('upload') && json.containsKey('download')) {
          final up = json['upload'] as int? ?? 0;
          final down = json['download'] as int? ?? 0;
          _uploadBytes = up;
          _downloadBytes = down;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// 添加日志条目（带时间戳，最多保留1000条）
  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] $message';
    _logs.add(logLine);
    if (_logs.length > 1000) {
      _logs.removeRange(0, _logs.length - 1000);
    }
    _logController.add(logLine);
  }

  /// 清空所有日志
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _logController.close();
    _process?.kill();
    // 释放时清理系统代理
    if (_config.systemProxy) {
      _removeSystemProxy();
    }
    super.dispose();
  }

  /// 启用系统代理（Windows注册表/macOS networksetup/Linux env）
  Future<void> _applySystemProxy() async {
    try {
      await SystemProxyService.enable(
        host: _config.localAddress,
        httpPort: _config.httpPort,
        socksPort: _config.socksPort,
      );
      _addLog('[ProxyService] System proxy enabled');
    } catch (e) {
      _addLog('[ProxyService] Failed to enable system proxy: $e');
    }
  }

  /// 禁用系统代理
  Future<void> _removeSystemProxy() async {
    try {
      await SystemProxyService.disable();
      _addLog('[ProxyService] System proxy disabled');
    } catch (e) {
      _addLog('[ProxyService] Failed to disable system proxy: $e');
    }
  }

  /// 设置系统代理开关（即时生效）
  ///
  /// 开启时若代理正在运行则立即设置系统代理
  /// 关闭时立即移除系统代理
  Future<void> setSystemProxy(bool enable) async {
    updateConfig(_config.copyWith(systemProxy: enable));

    if (enable && isRunning) {
      await _applySystemProxy();
    } else if (!enable) {
      await _removeSystemProxy();
    }
  }
}

/// 速度记录，用于绘制实时网速曲线图
class SpeedRecord {
  final DateTime time;
  final int upload;
  final int download;

  const SpeedRecord({
    required this.time,
    required this.upload,
    required this.download,
  });
}
