// Clash API 服务
// 通过 RESTful API 和 WebSocket 与代理内核（mihomo/sing-box）的 Clash API 通信
// 提供实时流量监控、日志流、节点列表、连接管理、代理模式切换等功能

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Clash API 服务 — 与内核外部控制器通信
///
/// 职责：
/// - WebSocket 实时流量监听（/traffic 端点）
/// - WebSocket 实时日志流（/logs 端点）
/// - RESTful API 节点列表查询（/proxies）
/// - RESTful API 代理切换（/proxies/:group）
/// - RESTful API 代理模式切换（/configs mode）
/// - RESTful API 连接管理（/connections）
/// - 自动断线重连（3秒间隔）
class ClashApiService extends ChangeNotifier {
  /// HTTP 客户端，用于 RESTful API 调用
  final Dio _dio = Dio();

  /// WebSocket 通道，用于实时流量监听
  WebSocketChannel? _wsChannel;

  /// WebSocket 订阅，用于取消流量监听
  StreamSubscription? _wsSubscription;

  /// Clash API 基础地址，默认 http://127.0.0.1:9090
  String _apiUrl = 'http://127.0.0.1:9090';

  /// Clash API 认证密钥
  String _secret = '';

  /// 实时上传速度（字节/秒）
  int _liveUpload = 0;

  /// 实时下载速度（字节/秒）
  int _liveDownload = 0;

  /// 当前活跃连接列表
  List<ClashConnection> _connections = [];

  /// 实时日志条目列表，最多保留500条
  List<ClashLogEntry> _realtimeLogs = [];

  /// 当前代理模式：rule（规则）/ global（全局）/ direct（直连）
  String _currentProxyMode = 'rule';

  // ---- 公开 Getter ----

  /// 实时上传速度（字节/秒）
  int get liveUpload => _liveUpload;

  /// 实时下载速度（字节/秒）
  int get liveDownload => _liveDownload;

  /// 当前活跃连接列表（不可变）
  List<ClashConnection> get connections => List.unmodifiable(_connections);

  /// 实时日志条目列表（不可变），最多500条
  List<ClashLogEntry> get realtimeLogs => List.unmodifiable(_realtimeLogs);

  /// 当前代理模式
  String get currentProxyMode => _currentProxyMode;

  /// WebSocket 是否已连接
  bool get isConnected => _wsChannel != null;

  /// 配置 Clash API 连接参数
  ///
  /// [apiUrl] API 基础地址，如 http://127.0.0.1:9090
  /// [secret] 认证密钥，可选
  void configure({required String apiUrl, String? secret}) {
    _apiUrl = apiUrl.replaceAll(RegExp(r'/$'), '');
    _secret = secret ?? '';
    _dio.options.baseUrl = _apiUrl;
    if (_secret.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_secret';
    }
  }

  /// 连接 Clash API WebSocket 实时流量和日志流
  ///
  /// 流程：
  /// 1. 断开已有连接
  /// 2. 建立 /traffic WebSocket 连接，监听实时上传/下载速度
  /// 3. 建立 /logs WebSocket 连接，监听实时日志
  /// 4. 连接异常或断开时自动重连（3秒间隔）
  Future<void> connect() async {
    await disconnect();

    try {
      final wsUrl = _apiUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/traffic?token=$_secret');
      _wsChannel = WebSocketChannel.connect(uri);

      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json.containsKey('up') && json.containsKey('down')) {
              _liveUpload = (json['up'] as num).toInt();
              _liveDownload = (json['down'] as num).toInt();
              notifyListeners();
            }
          } catch (_) {}
        },
        onError: (e) {
          debugPrint('[ClashApi] WebSocket error: $e');
          _reconnect();
        },
        onDone: () {
          debugPrint('[ClashApi] WebSocket closed');
          _reconnect();
        },
      );

      await _connectLogsStream();
      notifyListeners();
    } catch (e) {
      debugPrint('[ClashApi] Connect failed: $e');
    }
  }

  /// 连接 /logs WebSocket 日志流
  ///
  /// 监听内核实时日志输出，保留最近500条
  Future<void> _connectLogsStream() async {
    try {
      final wsUrl = _apiUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/logs?token=$_secret&level=info');
      final logChannel = WebSocketChannel.connect(uri);

      logChannel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final entry = ClashLogEntry(
              type: json['type'] as String? ?? 'info',
              payload: json['payload'] as String? ?? '',
            );
            _realtimeLogs = [..._realtimeLogs, entry];
            if (_realtimeLogs.length > 500) {
              _realtimeLogs = _realtimeLogs.sublist(_realtimeLogs.length - 500);
            }
            notifyListeners();
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  /// 自动重连定时器
  Timer? _reconnectTimer;

  /// 延迟3秒后自动重连 WebSocket
  void _reconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () => connect());
  }

  /// 断开 WebSocket 连接，重置流量数据
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _liveUpload = 0;
    _liveDownload = 0;
    notifyListeners();
  }

  /// 获取所有代理节点列表
  ///
  /// 调用 GET /proxies 接口，返回节点和代理组信息
  Future<List<ClashProxy>> getProxies() async {
    try {
      final resp = await _dio.get('/proxies');
      final data = resp.data as Map<String, dynamic>;
      final proxies = data['proxies'] as Map<String, dynamic>;
      return proxies.entries
          .map((e) => ClashProxy.fromJson(e.key, e.value as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 切换代理组中的选中节点
  ///
  /// [group] 代理组名称
  /// [name] 要切换到的节点名称
  Future<void> switchProxy(String group, String name) async {
    try {
      await _dio.put('/proxies/$group', data: {'name': name});
    } catch (_) {}
  }

  /// 切换代理模式
  ///
  /// [mode] 代理模式：rule / global / direct
  Future<void> setProxyMode(String mode) async {
    try {
      await _dio.patch('/configs', data: {'mode': mode});
      _currentProxyMode = mode;
      notifyListeners();
    } catch (_) {}
  }

  /// 获取当前所有活跃连接
  ///
  /// 调用 GET /connections 接口
  Future<void> fetchConnections() async {
    try {
      final resp = await _dio.get('/connections');
      final data = resp.data as Map<String, dynamic>;
      final conns = data['connections'] as List? ?? [];
      _connections = conns
          .map((c) => ClashConnection.fromJson(c as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  /// 关闭所有活跃连接
  ///
  /// 调用 DELETE /connections 接口
  Future<void> closeAllConnections() async {
    try {
      await _dio.delete('/connections');
      _connections.clear();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    super.dispose();
  }
}

/// Clash 代理节点/代理组数据模型
class ClashProxy {
  /// 节点/代理组名称
  final String name;

  /// 类型：Selector / URLTest / Fallback / Shadowsocks / VMess 等
  final String type;

  /// 代理组当前选中的节点名称，仅代理组有效
  final String? now;

  /// 延迟（毫秒），来自 history 数组最新记录
  final int? delay;

  /// 代理组包含的所有子节点名称列表
  final List<String> all;

  const ClashProxy({
    required this.name,
    required this.type,
    this.now,
    this.delay,
    this.all = const [],
  });

  /// 从 Clash API JSON 响应解析代理节点
  factory ClashProxy.fromJson(String name, Map<String, dynamic> json) {
    return ClashProxy(
      name: name,
      type: json['type'] as String? ?? '',
      now: json['now'] as String?,
      delay: json['history'] != null && (json['history'] as List).isNotEmpty
          ? (json['history'][0]['delay'] as num?)?.toInt()
          : null,
      all: (json['all'] as List?)?.cast<String>() ?? [],
    );
  }

  /// 是否为代理组（Selector / URLTest / Fallback）
  bool get isGroup => type == 'Selector' || type == 'URLTest' || type == 'Fallback';
}

/// Clash 活跃连接数据模型
class ClashConnection {
  /// 连接唯一标识
  final String id;

  /// 目标主机名
  final String host;

  /// 目标 IP 地址
  final String destinationIP;

  /// 目标端口
  final String destinationPort;

  /// 代理链（如 proxy → direct）
  final String chain;

  /// 上传字节数
  final int upload;

  /// 下载字节数
  final int download;

  /// 连接建立时间
  final DateTime start;

  const ClashConnection({
    required this.id,
    required this.host,
    this.destinationIP = '',
    this.destinationPort = '',
    this.chain = '',
    this.upload = 0,
    this.download = 0,
    required this.start,
  });

  /// 从 Clash API JSON 响应解析连接信息
  factory ClashConnection.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};
    return ClashConnection(
      id: json['id'] as String? ?? '',
      host: meta['host'] as String? ?? meta['destinationIP'] as String? ?? '',
      destinationIP: meta['destinationIP'] as String? ?? '',
      destinationPort: meta['destinationPort'] as String? ?? '',
      chain: (json['chains'] as List?)?.join(' → ') ?? '',
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Clash 日志条目数据模型
class ClashLogEntry {
  /// 日志级别：info / warning / error / debug
  final String type;

  /// 日志内容
  final String payload;

  const ClashLogEntry({required this.type, required this.payload});
}
