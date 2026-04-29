import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/config.dart';
import 'config_storage_service.dart';

class SubscriptionService extends ChangeNotifier {
  final Dio _dio = Dio();
  final ConfigStorageService _storage;

  List<SubscriptionInfo> _subscriptions = [];
  bool _isLoading = false;
  String? _error;
  Timer? _autoRefreshTimer;
  int _refreshMinutes = 0;
  Future<void> Function(List<NodeConfig>)? onNodesRefreshed;

  List<SubscriptionInfo> get subscriptions => List.unmodifiable(_subscriptions);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get refreshMinutes => _refreshMinutes;

  SubscriptionService(this._storage);

  Future<void> init() async {
    _subscriptions = _storage.loadSubscriptions();
    notifyListeners();
  }

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

  Future<void> _autoRefreshAll() async {
    if (_subscriptions.isEmpty) return;

    final allNodes = await refreshAll();
    if (allNodes.isNotEmpty && onNodesRefreshed != null) {
      await onNodesRefreshed!(allNodes);
    }
  }

  Future<void> addSubscription(SubscriptionInfo subscription) async {
    _subscriptions.add(subscription);
    await _save();
    notifyListeners();
  }

  Future<void> removeSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> updateSubscription(SubscriptionInfo subscription) async {
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index >= 0) {
      _subscriptions[index] = subscription;
      await _save();
      notifyListeners();
    }
  }

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

  Future<void> _save() async {
    await _storage.saveSubscriptions(_subscriptions);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
