// 订阅管理服务
// 负责代理订阅的增删改查、自动刷新、节点解析
// 支持 VMess / VLESS / Trojan / Shadowsocks / Hysteria2 协议解析

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/config.dart';
import 'config_storage_service.dart';

/// 订阅管理服务 — 管理代理订阅源和节点解析
///
/// 职责：
/// - 订阅源的增删改查和持久化
/// - 定时自动刷新订阅（可配置间隔）
/// - 从订阅 URL 下载并解析节点列表
/// - 支持多种协议解析：VMess / VLESS / Trojan / Shadowsocks / Hysteria2
/// - 节点刷新回调通知 ProxyService 更新节点列表
class SubscriptionService extends ChangeNotifier {
  /// HTTP 客户端，用于下载订阅内容
  final Dio _dio = Dio();

  /// 配置持久化存储服务
  final ConfigStorageService _storage;

  /// 订阅列表
  List<SubscriptionInfo> _subscriptions = [];

  /// 是否正在加载中
  bool _isLoading = false;

  /// 最近一次错误信息
  String? _error;

  /// 自动刷新定时器
  Timer? _autoRefreshTimer;

  /// 自动刷新间隔（分钟），0 表示不自动刷新
  int _refreshMinutes = 0;

  /// 节点刷新回调，订阅刷新后通知 ProxyService 更新节点
  Future<void> Function(List<NodeConfig>)? onNodesRefreshed;

  // ---- 公开 Getter ----

  /// 订阅列表（不可变）
  List<SubscriptionInfo> get subscriptions => List.unmodifiable(_subscriptions);

  /// 是否正在加载中
  bool get isLoading => _isLoading;

  /// 最近一次错误信息
  String? get error => _error;

  /// 自动刷新间隔（分钟）
  int get refreshMinutes => _refreshMinutes;

  SubscriptionService(this._storage);

  /// 初始化，从持久化存储加载订阅列表
  Future<void> init() async {
    _subscriptions = _storage.loadSubscriptions();
    notifyListeners();
  }

  /// 设置自动刷新间隔
  ///
  /// [minutes] 刷新间隔（分钟），0 表示关闭自动刷新
  void setupAutoRefresh(int minutes) {
    _autoRefreshTimer?.cancel();
    _refreshMinutes = minutes;

    if (minutes > 0) {
      _autoRefreshTimer = Timer.periodic(
        Duration(minutes: minutes),
        (_) => _autoRefreshAll(),
      );
    }
  }

  /// 自动刷新所有订阅
  ///
  /// 刷新完成后通过 onNodesRefreshed 回调通知 ProxyService
  Future<void> _autoRefreshAll() async {
    if (_subscriptions.isEmpty) return;

    final allNodes = await refreshAll();
    if (allNodes.isNotEmpty && onNodesRefreshed != null) {
      await onNodesRefreshed!(allNodes);
    }
  }

  /// 添加新订阅
  Future<void> addSubscription(SubscriptionInfo subscription) async {
    _subscriptions.add(subscription);
    await _save();
    notifyListeners();
  }

  /// 删除指定 ID 的订阅
  Future<void> removeSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
  }

  /// 更新订阅信息
  Future<void> updateSubscription(SubscriptionInfo subscription) async {
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index >= 0) {
      _subscriptions[index] = subscription;
      await _save();
      notifyListeners();
    }
  }

  /// 刷新指定订阅，返回解析后的节点列表
  ///
  /// 流程：
  /// 1. 根据 URL 下载订阅内容
  /// 2. 解析内容为节点列表
  /// 3. 更新订阅的最后刷新时间
  Future<List<NodeConfig>> refreshSubscription(String id) async {
    final sub = _subscriptions.firstWhere(
      (s) => s.id == id,
      orElse: () => throw Exception('Subscription not found'),
    );

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final nodes = await _fetchNodes(sub.url);

      final updated = sub.copyWith(lastUpdated: DateTime.now());
      final index = _subscriptions.indexWhere((s) => s.id == id);
      if (index >= 0) {
        _subscriptions[index] = updated;
      }
      await _save();

      _isLoading = false;
      notifyListeners();
      return nodes;
    } catch (e) {
      _isLoading = false;
      _error = 'Refresh failed: $e';
      notifyListeners();
      return [];
    }
  }

  /// 刷新所有订阅，返回合并后的节点列表
  Future<List<NodeConfig>> refreshAll() async {
    final allNodes = <NodeConfig>[];
    for (final sub in _subscriptions) {
      try {
        final nodes = await refreshSubscription(sub.id);
        allNodes.addAll(nodes);
      } catch (e) {
        debugPrint('SubscriptionService: refresh ${sub.name} failed: $e');
      }
    }
    return allNodes;
  }

  /// 从订阅 URL 下载内容
  ///
  /// 超时时间30秒，返回原始文本内容
  Future<List<NodeConfig>> _fetchNodes(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final content = response.data;
      if (content == null || content.isEmpty) return [];

      return _parseSubscriptionContent(content);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// 解析订阅内容为节点列表
  ///
  /// 逐行解析，支持以下协议 URI：
  /// - vmess:// Base64 编码的 JSON
  /// - vless:// URI 格式
  /// - trojan:// URI 格式
  /// - ss:// Base64 编码的 Shadowsocks URI
  /// - hysteria2:// / hy2:// URI 格式
  List<NodeConfig> _parseSubscriptionContent(String content) {
    final nodes = <NodeConfig>[];

    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('vmess://')) {
        final node = _parseVmess(trimmed);
        if (node != null) nodes.add(node);
      } else if (trimmed.startsWith('vless://')) {
        final node = _parseVless(trimmed);
        if (node != null) nodes.add(node);
      } else if (trimmed.startsWith('trojan://')) {
        final node = _parseTrojan(trimmed);
        if (node != null) nodes.add(node);
      } else if (trimmed.startsWith('ss://')) {
        final node = _parseShadowsocks(trimmed);
        if (node != null) nodes.add(node);
      } else if (trimmed.startsWith('hysteria2://') || trimmed.startsWith('hy2://')) {
        final node = _parseHysteria2(trimmed);
        if (node != null) nodes.add(node);
      }
    }

    return nodes;
  }

  /// 解析 VMess 协议 URI
  ///
  /// 格式：vmess://{Base64编码的JSON}
  /// JSON 字段：id(名称), add(地址), port(端口), id(UUID), aid(alterId), net(传输协议)
  NodeConfig? _parseVmess(String uri) {
    try {
      final encoded = uri.replaceFirst('vmess://', '');
      final decoded = utf8.decode(base64Decode(encoded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return NodeConfig(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['ps'] as String? ?? 'VMess',
        protocol: ProxyProtocol.vmess,
        address: json['add'] as String? ?? '',
        port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
        extra: {
          'uuid': json['id'],
          'alterId': json['aid'] ?? 0,
          'security': json['net'] ?? 'tcp',
          'network': json['net'] ?? 'tcp',
        },
      );
    } catch (e) {
      debugPrint('SubscriptionService: parseVmess error: $e');
      return null;
    }
  }

  /// 解析 VLESS 协议 URI
  ///
  /// 格式：vless://{uuid}@{host}:{port}?{params}#{name}
  /// 参数：flow, security, type, sni 等
  NodeConfig? _parseVless(String uri) {
    try {
      final parsed = Uri.parse(uri);
      final params = parsed.queryParameters;
      final name = params['name'] ?? parsed.fragment;
      final effectiveName = name.isEmpty ? 'VLESS' : name;
      return NodeConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: effectiveName,
        protocol: ProxyProtocol.vless,
        address: parsed.host,
        port: parsed.port,
        extra: {
          'uuid': parsed.userInfo,
          'flow': params['flow'],
          'security': params['security'] ?? 'none',
          'type': params['type'] ?? 'tcp',
        },
      );
    } catch (e) {
      debugPrint('SubscriptionService: parseVless error: $e');
      return null;
    }
  }

  /// 解析 Trojan 协议 URI
  ///
  /// 格式：trojan://{password}@{host}:{port}?{params}#{name}
  /// 参数：sni, type 等
  NodeConfig? _parseTrojan(String uri) {
    try {
      final parsed = Uri.parse(uri);
      final params = parsed.queryParameters;
      final name = params['name'] ?? parsed.fragment;
      final effectiveName = name.isEmpty ? 'Trojan' : name;
      return NodeConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: effectiveName,
        protocol: ProxyProtocol.trojan,
        address: parsed.host,
        port: parsed.port,
        extra: {
          'password': parsed.userInfo,
          'sni': params['sni'],
          'type': params['type'] ?? 'tcp',
        },
      );
    } catch (e) {
      debugPrint('SubscriptionService: parseTrojan error: $e');
      return null;
    }
  }

  /// 解析 Shadowsocks 协议 URI
  ///
  /// 格式：ss://{Base64(method:password)}@{host}:{port}#{name}
  NodeConfig? _parseShadowsocks(String uri) {
    try {
      final content = uri.replaceFirst('ss://', '');
      final hashIndex = content.indexOf('#');
      final name = hashIndex >= 0 ? Uri.decodeComponent(content.substring(hashIndex + 1)) : 'Shadowsocks';
      final body = hashIndex >= 0 ? content.substring(0, hashIndex) : content;

      final atIndex = body.indexOf('@');
      if (atIndex < 0) return null;

      final methodAndPassword = utf8.decode(base64Decode(body.substring(0, atIndex)));
      final colonIndex = methodAndPassword.indexOf(':');
      final method = methodAndPassword.substring(0, colonIndex);
      final password = methodAndPassword.substring(colonIndex + 1);

      final serverPart = body.substring(atIndex + 1);
      final colonPos = serverPart.lastIndexOf(':');

      return NodeConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        protocol: ProxyProtocol.shadowsocks,
        address: serverPart.substring(0, colonPos),
        port: int.parse(serverPart.substring(colonPos + 1)),
        extra: {
          'method': method,
          'password': password,
        },
      );
    } catch (e) {
      debugPrint('SubscriptionService: parseShadowsocks error: $e');
      return null;
    }
  }

  /// 解析 Hysteria2 协议 URI
  ///
  /// 格式：hysteria2://{password}@{host}:{port}?{params}#{name}
  /// 参数：sni, insecure 等
  NodeConfig? _parseHysteria2(String uri) {
    try {
      final parsed = Uri.parse(uri);
      final params = parsed.queryParameters;
      final name = params['name'] ?? parsed.fragment;
      final effectiveName = name.isEmpty ? 'Hysteria2' : name;
      return NodeConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: effectiveName,
        protocol: ProxyProtocol.hysteria2,
        address: parsed.host,
        port: parsed.port,
        extra: {
          'password': parsed.userInfo,
          'sni': params['sni'],
          'insecure': params['insecure'] == '1',
        },
      );
    } catch (e) {
      debugPrint('SubscriptionService: parseHysteria2 error: $e');
      return null;
    }
  }

  /// 持久化保存订阅列表
  Future<void> _save() async {
    await _storage.saveSubscriptions(_subscriptions);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
