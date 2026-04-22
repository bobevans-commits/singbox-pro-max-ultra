import 'package:flutter/foundation.dart';

/// 内核类型枚举
enum KernelType {
  singBox,
  mihomo,
  v2Ray,
}

extension KernelTypeExtension on KernelType {
  String get name {
    switch (this) {
      case KernelType.singBox:
        return 'sing-box';
      case KernelType.mihomo:
        return 'mihomo';
      case KernelType.v2Ray:
        return 'v2ray';
    }
  }

  static KernelType fromName(String name) {
    switch (name.toLowerCase()) {
      case 'sing-box':
      case 'singbox':
        return KernelType.singBox;
      case 'mihomo':
      case 'clash-meta':
        return KernelType.mihomo;
      case 'v2ray':
      case 'v2ray-core':
        return KernelType.v2Ray;
      default:
        return KernelType.singBox;
    }
  }
}

/// 内核状态枚举
enum KernelStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

extension KernelStatusExtension on KernelStatus {
  String get description {
    switch (this) {
      case KernelStatus.stopped:
        return '已停止';
      case KernelStatus.starting:
        return '启动中...';
      case KernelStatus.running:
        return '运行中';
      case KernelStatus.stopping:
        return '停止中...';
      case KernelStatus.error:
        return '错误';
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case KernelStatus.stopped:
        return Colors.grey;
      case KernelStatus.starting:
        return Colors.orange;
      case KernelStatus.running:
        return Colors.green;
      case KernelStatus.stopping:
        return Colors.orange;
      case KernelStatus.error:
        return Colors.red;
    }
  }
}

/// 节点配置模型
class NodeConfig {
  final String name;
  final String type;
  final String server;
  final int port;
  final String? uuid;
  final String? password;
  final String? method;

  NodeConfig({
    required this.name,
    required this.type,
    required this.server,
    required this.port,
    this.uuid,
    this.password,
    this.method,
  });

  factory NodeConfig.fromJson(Map<String, dynamic> json) {
    return NodeConfig(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      server: json['server'] ?? '',
      port: json['port'] ?? 0,
      uuid: json['uuid'],
      password: json['password'],
      method: json['method'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'server': server,
      'port': port,
      if (uuid != null) 'uuid': uuid,
      if (password != null) 'password': password,
      if (method != null) 'method': method,
    };
  }
}

/// 代理配置模型
class ProxyConfig {
  final String kernelType;
  final String logLevel;
  final int httpPort;
  final int socksPort;
  final List<NodeConfig> nodes;
  final String? defaultNode;

  ProxyConfig({
    this.kernelType = 'sing-box',
    this.logLevel = 'info',
    this.httpPort = 7890,
    this.socksPort = 7891,
    this.nodes = const [],
    this.defaultNode,
  });

  factory ProxyConfig.fromJson(Map<String, dynamic> json) {
    return ProxyConfig(
      kernelType: json['kernel_type'] ?? 'sing-box',
      logLevel: json['log_level'] ?? 'info',
      httpPort: json['http_port'] ?? 7890,
      socksPort: json['socks_port'] ?? 7891,
      nodes: (json['nodes'] as List?)
              ?.map((e) => NodeConfig.fromJson(e))
              .toList() ??
          [],
      defaultNode: json['default_node'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kernel_type': kernelType,
      'log_level': logLevel,
      'http_port': httpPort,
      'socks_port': socksPort,
      'nodes': nodes.map((e) => e.toJson()).toList(),
      if (defaultNode != null) 'default_node': defaultNode,
    };
  }
}
