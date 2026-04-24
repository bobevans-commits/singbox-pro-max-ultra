
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/config.dart';

class ConfigStorageService {
  static const _keyProxyConfig = 'proxy_config';
  static const _keyNodes = 'nodes';
  static const _keyRoutingRules = 'routing_rules';
  static const _keyActiveKernel = 'active_kernel';
  static const _keySubscriptions = 'subscriptions';

  SharedPreferences? _prefs;

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('ConfigStorageService not initialized');
    return _prefs!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ProxyConfig
  ProxyConfig loadProxyConfig() {
    try {
      final jsonStr = prefs.getString(_keyProxyConfig);
      if (jsonStr != null) {
        return ProxyConfig.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('ConfigStorageService: loadProxyConfig error: $e');
    }
    return ProxyConfig();
  }

  Future<bool> saveProxyConfig(ProxyConfig config) async {
    try {
      final jsonStr = jsonEncode(config.toJson());
      return prefs.setString(_keyProxyConfig, jsonStr);
    } catch (e) {
      debugPrint('ConfigStorageService: saveProxyConfig error: $e');
      return false;
    }
  }

  // Nodes
  List<NodeConfig> loadNodes() {
    try {
      final jsonStr = prefs.getString(_keyNodes);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        return list
            .map((n) => NodeConfig.fromJson(n as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('ConfigStorageService: loadNodes error: $e');
    }
    return [];
  }

  Future<bool> saveNodes(List<NodeConfig> nodes) async {
    try {
      final jsonStr = jsonEncode(nodes.map((n) => n.toJson()).toList());
      return prefs.setString(_keyNodes, jsonStr);
    } catch (e) {
      debugPrint('ConfigStorageService: saveNodes error: $e');
      return false;
    }
  }

  // RoutingRules
  List<RoutingRule> loadRoutingRules() {
    try {
      final jsonStr = prefs.getString(_keyRoutingRules);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        return list
            .map((r) => RoutingRule.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('ConfigStorageService: loadRoutingRules error: $e');
    }
    return [];
  }

  Future<bool> saveRoutingRules(List<RoutingRule> rules) async {
    try {
      final jsonStr = jsonEncode(rules.map((r) => r.toJson()).toList());
      return prefs.setString(_keyRoutingRules, jsonStr);
    } catch (e) {
      debugPrint('ConfigStorageService: saveRoutingRules error: $e');
      return false;
    }
  }

  // ActiveKernel
  KernelType loadActiveKernel() {
    final name = prefs.getString(_keyActiveKernel);
    if (name != null) {
      return KernelType.fromName(name);
    }
    return KernelType.singbox;
  }

  Future<bool> saveActiveKernel(KernelType type) async {
    return prefs.setString(_keyActiveKernel, type.name);
  }

  // Subscriptions
  List<SubscriptionInfo> loadSubscriptions() {
    try {
      final jsonStr = prefs.getString(_keySubscriptions);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        return list
            .map((s) => SubscriptionInfo.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('ConfigStorageService: loadSubscriptions error: $e');
    }
    return [];
  }

  Future<bool> saveSubscriptions(List<SubscriptionInfo> subscriptions) async {
    try {
      final jsonStr = jsonEncode(subscriptions.map((s) => s.toJson()).toList());
      return prefs.setString(_keySubscriptions, jsonStr);
    } catch (e) {
      debugPrint('ConfigStorageService: saveSubscriptions error: $e');
      return false;
    }
  }

  // Import/Export
  Future<String> exportConfig() async {
    final config = loadProxyConfig();
    final nodes = loadNodes();
    final rules = loadRoutingRules();
    final subs = loadSubscriptions();
    final kernel = loadActiveKernel();

    final exportData = {
      'proxy_config': config.toJson(),
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'routing_rules': rules.map((r) => r.toJson()).toList(),
      'subscriptions': subs.map((s) => s.toJson()).toList(),
      'active_kernel': kernel.name,
      'export_time': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  Future<bool> importConfig(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (data['proxy_config'] != null) {
        await saveProxyConfig(
          ProxyConfig.fromJson(data['proxy_config'] as Map<String, dynamic>),
        );
      }

      if (data['nodes'] != null) {
        await saveNodes(
          (data['nodes'] as List)
              .map((n) => NodeConfig.fromJson(n as Map<String, dynamic>))
              .toList(),
        );
      }

      if (data['routing_rules'] != null) {
        await saveRoutingRules(
          (data['routing_rules'] as List)
              .map((r) => RoutingRule.fromJson(r as Map<String, dynamic>))
              .toList(),
        );
      }

      if (data['subscriptions'] != null) {
        await saveSubscriptions(
          (data['subscriptions'] as List)
              .map((s) => SubscriptionInfo.fromJson(s as Map<String, dynamic>))
              .toList(),
        );
      }

      if (data['active_kernel'] != null) {
        await saveActiveKernel(KernelType.fromName(data['active_kernel'] as String));
      }

      return true;
    } catch (e) {
      debugPrint('ConfigStorageService: importConfig error: $e');
      return false;
    }
  }

  Future<String> get configDirPath async {
    final appDir = await getApplicationSupportDirectory();
    return appDir.path;
  }

  Future<String> saveConfigFile(String filename, String content) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    return file.path;
  }

  Future<String?> readConfigFile(String filename) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$filename');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }
}

class SubscriptionInfo {
  final String id;
  final String name;
  final String url;
  final int updateIntervalMinutes;
  final DateTime? lastUpdated;

  const SubscriptionInfo({
    required this.id,
    required this.name,
    required this.url,
    this.updateIntervalMinutes = 60,
    this.lastUpdated,
  });

  SubscriptionInfo copyWith({
    String? id,
    String? name,
    String? url,
    int? updateIntervalMinutes,
    DateTime? lastUpdated,
  }) {
    return SubscriptionInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      updateIntervalMinutes: updateIntervalMinutes ?? this.updateIntervalMinutes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'update_interval_minutes': updateIntervalMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
      };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) => SubscriptionInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        updateIntervalMinutes: json['update_interval_minutes'] as int? ?? 60,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
      );
}
