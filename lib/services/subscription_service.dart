import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/singbox_config.dart';

/// Subscription model
class Subscription {
  final String id;
  final String name;
  final String url;
  final DateTime? lastUpdated;
  final int nodeCount;
  final bool autoUpdate;
  final Duration updateInterval;

  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.lastUpdated,
    this.nodeCount = 0,
    this.autoUpdate = false,
    this.updateInterval = const Duration(hours: 6),
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'nodeCount': nodeCount,
        'autoUpdate': autoUpdate,
        'updateIntervalSeconds': updateInterval.inSeconds,
      };

  static Subscription fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : null,
      nodeCount: json['nodeCount'] ?? 0,
      autoUpdate: json['autoUpdate'] ?? false,
      updateInterval: Duration(seconds: json['updateIntervalSeconds'] ?? 21600),
    );
  }

  Subscription copyWith({
    String? id,
    String? name,
    String? url,
    DateTime? lastUpdated,
    int? nodeCount,
    bool? autoUpdate,
    Duration? updateInterval,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      nodeCount: nodeCount ?? this.nodeCount,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      updateInterval: updateInterval ?? this.updateInterval,
    );
  }
}

/// Subscription service for managing proxy subscriptions
class SubscriptionService extends ChangeNotifier {
  final List<Subscription> _subscriptions = [];
  bool _isUpdating = false;
  String? _errorMessage;

  // Getters
  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;

  /// Add a new subscription
  Future<void> addSubscription({
    required String name,
    required String url,
    bool autoUpdate = false,
    Duration updateInterval = const Duration(hours: 6),
  }) async {
    try {
      // Validate URL
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw Exception('Invalid URL format. Must start with http:// or https://');
      }

      final subscription = Subscription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: url,
        autoUpdate: autoUpdate,
        updateInterval: updateInterval,
      );

      _subscriptions.add(subscription);
      notifyListeners();

      // Auto-fetch after adding
      await updateSubscription(subscription.id);
    } catch (e) {
      _errorMessage = 'Failed to add subscription: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Remove a subscription
  void removeSubscription(String id) {
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Update subscription info
  void updateSubscriptionInfo(String id, {String? name, String? url, bool? autoUpdate}) {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final sub = _subscriptions[index];
    _subscriptions[index] = sub.copyWith(
      name: name,
      url: url,
      autoUpdate: autoUpdate,
    );
    notifyListeners();
  }

  /// Fetch and parse subscription from URL
  Future<void> updateSubscription(String id) async {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index == -1) throw Exception('Subscription not found');

    final subscription = _subscriptions[index];
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(subscription.url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch subscription: ${response.statusCode}');
      }

      final body = response.body;
      final nodes = await _parseSubscription(body);

      _subscriptions[index] = subscription.copyWith(
        lastUpdated: DateTime.now(),
        nodeCount: nodes.length,
      );

      _isUpdating = false;
      notifyListeners();
    } catch (e) {
      _isUpdating = false;
      _errorMessage = 'Update failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Parse subscription content (supports base64 encoded list and JSON)
  Future<List<Outbound>> _parseSubscription(String content) async {
    final List<Outbound> outbounds = [];

    // Try to decode as base64 (common format for subscription links)
    String decodedContent;
    try {
      decodedContent = utf8.decode(base64Decode(content));
    } catch (_) {
      decodedContent = content;
    }

    // Try to parse as JSON first
    try {
      final jsonMap = jsonDecode(decodedContent);
      if (jsonMap is Map<String, dynamic>) {
        // Could be sing-box config or clash config
        if (jsonMap.containsKey('outbounds')) {
          // sing-box format
          final outboundsList = jsonMap['outbounds'] as List;
          for (var item in outboundsList) {
            if (item is Map<String, dynamic> && item['type'] != null) {
              outbounds.add(Outbound.fromJson(item));
            }
          }
        } else if (jsonMap.containsKey('proxies')) {
          // Clash format - would need conversion
          // For now, skip clash format
        }
      }
    } catch (_) {
      // Not JSON, try line-by-line parsing (base64 encoded links)
      final lines = decodedContent.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        final outbound = _parseLink(line);
        if (outbound != null) {
          outbounds.add(outbound);
        }
      }
    }

    return outbounds;
  }

  /// Parse a single proxy link (vmess://, vless://, trojan://, etc.)
  Outbound? _parseLink(String link) {
    try {
      if (link.startsWith('vmess://')) {
        return _parseVmess(link);
      } else if (link.startsWith('vless://')) {
        return _parseVless(link);
      } else if (link.startsWith('trojan://')) {
        return _parseTrojan(link);
      } else if (link.startsWith('ss://')) {
        return _parseShadowsocks(link);
      } else if (link.startsWith('hysteria://') || link.startsWith('hysteria2://')) {
        return _parseHysteria(link);
      } else if (link.startsWith('tuic://')) {
        return _parseTuic(link);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Outbound? _parseVmess(String link) {
    final base64Data = link.substring(8);
    String decoded;
    try {
      decoded = utf8.decode(base64Decode(base64Data));
    } catch (_) {
      return null;
    }

    try {
      final jsonMap = jsonDecode(decoded);
      return Outbound(
        type: 'vmess',
        tag: jsonMap['ps'] ?? 'vmess-${DateTime.now().millisecondsSinceEpoch}',
        server: jsonMap['add'],
        serverPort: int.tryParse(jsonMap['port']?.toString() ?? ''),
        uuid: jsonMap['id'],
        security: jsonMap['scy'] ?? 'auto',
        tls: jsonMap['tls'] == 'tls' 
            ? TlsConfig(
                enabled: true,
                serverName: jsonMap['sni'] ?? jsonMap['add'],
              )
            : null,
        transport: jsonMap['net'] != null
            ? TransportConfig(
                type: jsonMap['net'],
                path: jsonMap['path'],
                serviceName: jsonMap['path'],
              )
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  Outbound? _parseVless(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    return Outbound(
      type: 'vless',
      tag: uri.fragment.isNotEmpty ? uri.fragment : 'vless-${DateTime.now().millisecondsSinceEpoch}',
      server: uri.host,
      serverPort: uri.port,
      uuid: uri.username,
      flow: uri.queryParameters['flow'],
      security: uri.queryParameters['security'],
      tls: uri.queryParameters['security'] == 'tls' || uri.queryParameters['security'] == 'reality'
          ? TlsConfig(
              enabled: true,
              serverName: uri.queryParameters['sni'] ?? uri.host,
            )
          : null,
      reality: uri.queryParameters['security'] == 'reality'
          ? RealityConfig(
              enabled: true,
              publicKey: uri.queryParameters['pbk'],
              shortId: uri.queryParameters['sid'],
            )
          : null,
      transport: uri.queryParameters['type'] != null
          ? TransportConfig(
              type: uri.queryParameters['type']!,
              path: uri.queryParameters['path'],
              serviceName: uri.queryParameters['serviceName'],
            )
          : null,
    );
  }

  Outbound? _parseTrojan(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    return Outbound(
      type: 'trojan',
      tag: uri.fragment.isNotEmpty ? uri.fragment : 'trojan-${DateTime.now().millisecondsSinceEpoch}',
      server: uri.host,
      serverPort: uri.port,
      password: uri.username,
      tls: TlsConfig(
        enabled: true,
        serverName: uri.queryParameters['sni'] ?? uri.host,
      ),
      transport: uri.queryParameters['type'] != null
          ? TransportConfig(
              type: uri.queryParameters['type']!,
              path: uri.queryParameters['path'],
              serviceName: uri.queryParameters['serviceName'],
            )
          : null,
    );
  }

  Outbound? _parseShadowsocks(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    String? password;
    String? method;

    // Handle both new and old format
    if (uri.username.contains(':')) {
      final parts = uri.username.split(':');
      method = parts[0];
      password = parts[1];
    } else {
      // Old format: base64 encoded method:password
      try {
        final decoded = utf8.decode(base64Decode(uri.username));
        final parts = decoded.split(':');
        method = parts[0];
        password = parts[1];
      } catch (_) {
        return null;
      }
    }

    return Outbound(
      type: 'shadowsocks',
      tag: uri.fragment.isNotEmpty ? uri.fragment : 'ss-${DateTime.now().millisecondsSinceEpoch}',
      server: uri.host,
      serverPort: uri.port,
      password: password,
    );
  }

  Outbound? _parseHysteria(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    final isHysteria2 = link.startsWith('hysteria2://');

    return Outbound(
      type: isHysteria2 ? 'hysteria2' : 'hysteria',
      tag: uri.fragment.isNotEmpty ? uri.fragment : 'hysteria-${DateTime.now().millisecondsSinceEpoch}',
      server: uri.host,
      serverPort: uri.port,
      obfsPassword: uri.queryParameters['obfsParam'],
      upMbps: uri.queryParameters['upmbps'],
      downMbps: uri.queryParameters['downmbps'],
      tls: TlsConfig(
        enabled: true,
        serverName: uri.queryParameters['sni'] ?? uri.host,
        insecure: uri.queryParameters['insecure'] == '1',
      ),
    );
  }

  Outbound? _parseTuic(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    return Outbound(
      type: 'tuic',
      tag: uri.fragment.isNotEmpty ? uri.fragment : 'tuic-${DateTime.now().millisecondsSinceEpoch}',
      server: uri.host,
      serverPort: uri.port,
      uuid: uri.username,
      password: uri.password,
      congestionControl: uri.queryParameters['congestion_control'],
    );
  }

  /// Update all subscriptions
  Future<void> updateAllSubscriptions() async {
    for (final sub in _subscriptions) {
      if (sub.autoUpdate) {
        await updateSubscription(sub.id);
      }
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
