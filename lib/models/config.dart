import 'dart:convert';

enum KernelType {
  singbox('sing-box', 'SagerNet/sing-box'),
  mihomo('mihomo', 'MetaCubeX/mihomo'),
  v2ray('v2ray', 'XTLS/Xray-core');

  final String label;
  final String repo;
  const KernelType(this.label, this.repo);

  static KernelType fromName(String name) {
    return KernelType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => KernelType.singbox,
    );
  }
}

enum KernelStatus {
  notInstalled,
  downloading,
  installing,
  installed,
  running,
  stopping,
  error;

  String get description {
    switch (this) {
      case KernelStatus.notInstalled:
        return '未安装';
      case KernelStatus.downloading:
        return '下载中';
      case KernelStatus.installing:
        return '安装中';
      case KernelStatus.installed:
        return '已安装';
      case KernelStatus.running:
        return '运行中';
      case KernelStatus.stopping:
        return '停止中';
      case KernelStatus.error:
        return '错误';
    }
  }
}

enum ProxyProtocol {
  vmess,
  vless,
  trojan,
  shadowsocks,
  hysteria,
  hysteria2,
  tuic,
  naive,
  wireguard;

  String get label {
    switch (this) {
      case ProxyProtocol.vmess:
        return 'VMess';
      case ProxyProtocol.vless:
        return 'VLESS';
      case ProxyProtocol.trojan:
        return 'Trojan';
      case ProxyProtocol.shadowsocks:
        return 'Shadowsocks';
      case ProxyProtocol.hysteria:
        return 'Hysteria';
      case ProxyProtocol.hysteria2:
        return 'Hysteria2';
      case ProxyProtocol.tuic:
        return 'TUIC';
      case ProxyProtocol.naive:
        return 'Naive';
      case ProxyProtocol.wireguard:
        return 'WireGuard';
    }
  }

  static ProxyProtocol fromString(String s) {
    return ProxyProtocol.values.firstWhere(
      (e) => e.name.toLowerCase() == s.toLowerCase(),
      orElse: () => ProxyProtocol.vmess,
    );
  }
}

class NodeConfig {
  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String address;
  final int port;
  final Map<String, dynamic> extra;

  NodeConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.port,
    this.extra = const {},
  });

  NodeConfig copyWith({
    String? id,
    String? name,
    ProxyProtocol? protocol,
    String? address,
    int? port,
    Map<String, dynamic>? extra,
  }) {
    return NodeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      address: address ?? this.address,
      port: port ?? this.port,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'address': address,
        'port': port,
        'extra': extra,
      };

  factory NodeConfig.fromJson(Map<String, dynamic> json) => NodeConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol: ProxyProtocol.fromString(json['protocol'] as String),
        address: json['address'] as String,
        port: json['port'] as int,
        extra: Map<String, dynamic>.from(json['extra'] as Map? ?? {}),
      );

  String toJsonString() => jsonEncode(toJson());

  factory NodeConfig.fromJsonString(String s) =>
      NodeConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class ProxyConfig {
  final KernelType kernelType;
  final String localAddress;
  final int localPort;
  final int socksPort;
  final int httpPort;
  final bool tunEnabled;
  final bool systemProxy;
  final List<NodeConfig> nodes;

  ProxyConfig({
    this.kernelType = KernelType.singbox,
    this.localAddress = '127.0.0.1',
    this.localPort = 1080,
    this.socksPort = 1080,
    this.httpPort = 1081,
    this.tunEnabled = false,
    this.systemProxy = false,
    this.nodes = const [],
  });

  ProxyConfig copyWith({
    KernelType? kernelType,
    String? localAddress,
    int? localPort,
    int? socksPort,
    int? httpPort,
    bool? tunEnabled,
    bool? systemProxy,
    List<NodeConfig>? nodes,
  }) {
    return ProxyConfig(
      kernelType: kernelType ?? this.kernelType,
      localAddress: localAddress ?? this.localAddress,
      localPort: localPort ?? this.localPort,
      socksPort: socksPort ?? this.socksPort,
      httpPort: httpPort ?? this.httpPort,
      tunEnabled: tunEnabled ?? this.tunEnabled,
      systemProxy: systemProxy ?? this.systemProxy,
      nodes: nodes ?? this.nodes,
    );
  }

  Map<String, dynamic> toJson() => {
        'kernel_type': kernelType.name,
        'local_address': localAddress,
        'local_port': localPort,
        'socks_port': socksPort,
        'http_port': httpPort,
        'tun_enabled': tunEnabled,
        'system_proxy': systemProxy,
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        kernelType: KernelType.fromName(json['kernel_type'] as String? ?? 'singbox'),
        localAddress: json['local_address'] as String? ?? '127.0.0.1',
        localPort: json['local_port'] as int? ?? 1080,
        socksPort: json['socks_port'] as int? ?? 1080,
        httpPort: json['http_port'] as int? ?? 1081,
        tunEnabled: json['tun_enabled'] as bool? ?? false,
        systemProxy: json['system_proxy'] as bool? ?? false,
        nodes: (json['nodes'] as List?)
                ?.map((n) => NodeConfig.fromJson(n as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class RoutingRule {
  final String id;
  final String name;
  final String type;
  final String match;
  final String target;
  final bool enabled;

  RoutingRule({
    required this.id,
    required this.name,
    this.type = 'domain',
    this.match = '',
    this.target = 'proxy',
    this.enabled = true,
  });

  static const typeOptions = ['domain', 'ip', 'protocol', 'port'];
  static const targetOptions = ['proxy', 'direct', 'block'];

  RoutingRule copyWith({
    String? id,
    String? name,
    String? type,
    String? match,
    String? target,
    bool? enabled,
  }) {
    return RoutingRule(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      match: match ?? this.match,
      target: target ?? this.target,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'match': match,
        'target': target,
        'enabled': enabled,
      };

  factory RoutingRule.fromJson(Map<String, dynamic> json) => RoutingRule(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'domain',
        match: json['match'] as String? ?? '',
        target: json['target'] as String? ?? 'proxy',
        enabled: json['enabled'] as bool? ?? true,
      );
}
