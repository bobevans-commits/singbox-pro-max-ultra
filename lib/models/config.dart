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
  int? latencyMs;
  double? downloadSpeed;

  NodeConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.port,
    this.extra = const {},
    this.latencyMs,
    this.downloadSpeed,
  });

  NodeConfig copyWith({
    String? id,
    String? name,
    ProxyProtocol? protocol,
    String? address,
    int? port,
    Map<String, dynamic>? extra,
    int? latencyMs,
    double? downloadSpeed,
  }) {
    return NodeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      address: address ?? this.address,
      port: port ?? this.port,
      extra: extra ?? this.extra,
      latencyMs: latencyMs ?? this.latencyMs,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
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

enum DnsMode {
  system('system', '系统 DNS'),
  custom('custom', '自定义'),
  doh('doh', 'DNS-over-HTTPS'),
  dot('dot', 'DNS-over-TLS');

  final String value;
  final String label;
  const DnsMode(this.value, this.label);

  static DnsMode fromString(String s) {
    return DnsMode.values.firstWhere(
      (e) => e.value == s,
      orElse: () => DnsMode.system,
    );
  }
}

class DnsConfig {
  final DnsMode mode;
  final List<String> servers;
  final List<String> fallbackServers;
  final bool remoteResolve;
  final String dohUrl;
  final String dotServer;

  const DnsConfig({
    this.mode = DnsMode.system,
    this.servers = const ['8.8.8.8', '1.1.1.1'],
    this.fallbackServers = const ['223.5.5.5', '119.29.29.29'],
    this.remoteResolve = false,
    this.dohUrl = 'https://dns.google/dns-query',
    this.dotServer = 'dns.google',
  });

  DnsConfig copyWith({
    DnsMode? mode,
    List<String>? servers,
    List<String>? fallbackServers,
    bool? remoteResolve,
    String? dohUrl,
    String? dotServer,
  }) {
    return DnsConfig(
      mode: mode ?? this.mode,
      servers: servers ?? this.servers,
      fallbackServers: fallbackServers ?? this.fallbackServers,
      remoteResolve: remoteResolve ?? this.remoteResolve,
      dohUrl: dohUrl ?? this.dohUrl,
      dotServer: dotServer ?? this.dotServer,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'servers': servers,
        'fallback_servers': fallbackServers,
        'remote_resolve': remoteResolve,
        'doh_url': dohUrl,
        'dot_server': dotServer,
      };

  factory DnsConfig.fromJson(Map<String, dynamic> json) => DnsConfig(
        mode: DnsMode.fromString(json['mode'] as String? ?? 'system'),
        servers: (json['servers'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const ['8.8.8.8', '1.1.1.1'],
        fallbackServers: (json['fallback_servers'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const ['223.5.5.5', '119.29.29.29'],
        remoteResolve: json['remote_resolve'] as bool? ?? false,
        dohUrl: json['doh_url'] as String? ?? 'https://dns.google/dns-query',
        dotServer: json['dot_server'] as String? ?? 'dns.google',
      );
}

class ProxyConfig {
  final KernelType kernelType;
  final String localAddress;
  final int localPort;
  final int socksPort;
  final int httpPort;
  final bool tunEnabled;
  final bool systemProxy;
  final bool lanSharing;
  final bool adBlocking;
  final bool smartNode;
  final List<NodeConfig> nodes;
  final DnsConfig dnsConfig;

  ProxyConfig({
    this.kernelType = KernelType.singbox,
    this.localAddress = '127.0.0.1',
    this.localPort = 1080,
    this.socksPort = 1080,
    this.httpPort = 1081,
    this.tunEnabled = false,
    this.systemProxy = false,
    this.lanSharing = false,
    this.adBlocking = false,
    this.smartNode = false,
    this.nodes = const [],
    this.dnsConfig = const DnsConfig(),
  });

  ProxyConfig copyWith({
    KernelType? kernelType,
    String? localAddress,
    int? localPort,
    int? socksPort,
    int? httpPort,
    bool? tunEnabled,
    bool? systemProxy,
    bool? lanSharing,
    bool? adBlocking,
    bool? smartNode,
    List<NodeConfig>? nodes,
    DnsConfig? dnsConfig,
  }) {
    return ProxyConfig(
      kernelType: kernelType ?? this.kernelType,
      localAddress: localAddress ?? this.localAddress,
      localPort: localPort ?? this.localPort,
      socksPort: socksPort ?? this.socksPort,
      httpPort: httpPort ?? this.httpPort,
      tunEnabled: tunEnabled ?? this.tunEnabled,
      systemProxy: systemProxy ?? this.systemProxy,
      lanSharing: lanSharing ?? this.lanSharing,
      adBlocking: adBlocking ?? this.adBlocking,
      smartNode: smartNode ?? this.smartNode,
      nodes: nodes ?? this.nodes,
      dnsConfig: dnsConfig ?? this.dnsConfig,
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
        'lan_sharing': lanSharing,
        'ad_blocking': adBlocking,
        'smart_node': smartNode,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'dns_config': dnsConfig.toJson(),
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        kernelType:
            KernelType.fromName(json['kernel_type'] as String? ?? 'singbox'),
        localAddress: json['local_address'] as String? ?? '127.0.0.1',
        localPort: json['local_port'] as int? ?? 1080,
        socksPort: json['socks_port'] as int? ?? 1080,
        httpPort: json['http_port'] as int? ?? 1081,
        tunEnabled: json['tun_enabled'] as bool? ?? false,
        systemProxy: json['system_proxy'] as bool? ?? false,
        lanSharing: json['lan_sharing'] as bool? ?? false,
        adBlocking: json['ad_blocking'] as bool? ?? false,
        smartNode: json['smart_node'] as bool? ?? false,
        nodes: (json['nodes'] as List?)
                ?.map((n) => NodeConfig.fromJson(n as Map<String, dynamic>))
                .toList() ??
            [],
        dnsConfig: json['dns_config'] != null
            ? DnsConfig.fromJson(json['dns_config'] as Map<String, dynamic>)
            : const DnsConfig(),
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

  static const typeOptions = [
    'domain',
    'domain_keyword',
    'domain_suffix',
    'ip_cidr',
    'geoip',
    'geosite',
    'process',
    'protocol',
    'port',
  ];

  static const targetOptions = ['proxy', 'direct', 'block'];

  static const presetRules = [
    RoutingRule._preset('国内直连', 'geosite', 'cn', 'direct'),
    RoutingRule._preset('国内IP直连', 'geoip', 'cn', 'direct'),
    RoutingRule._preset('广告屏蔽', 'geosite', 'category-ads-all', 'block'),
    RoutingRule._preset('私有网络', 'ip_cidr', '10.0.0.0/8', 'direct'),
    RoutingRule._preset('局域网', 'ip_cidr', '192.168.0.0/16', 'direct'),
    RoutingRule._preset('Google', 'geosite', 'google', 'proxy'),
    RoutingRule._preset('GitHub', 'geosite', 'github', 'proxy'),
    RoutingRule._preset('Telegram', 'geosite', 'telegram', 'proxy'),
    RoutingRule._preset('Twitter/X', 'geosite', 'twitter', 'proxy'),
    RoutingRule._preset('YouTube', 'geosite', 'youtube', 'proxy'),
    RoutingRule._preset('Netflix', 'geosite', 'netflix', 'proxy'),
    RoutingRule._preset('OpenAI', 'domain_keyword', 'openai', 'proxy'),
    RoutingRule._preset('Microsoft', 'geosite', 'microsoft', 'direct'),
    RoutingRule._preset('Apple', 'geosite', 'apple', 'direct'),
  ];

  const RoutingRule._preset(this.name, this.type, this.match, this.target)
      : id = '',
        enabled = true;

  String get typeLabel {
    switch (type) {
      case 'domain':
        return '域名';
      case 'domain_keyword':
        return '域名关键词';
      case 'domain_suffix':
        return '域名后缀';
      case 'ip_cidr':
        return 'IP/CIDR';
      case 'geoip':
        return 'GeoIP';
      case 'geosite':
        return 'GeoSite';
      case 'process':
        return '进程';
      case 'protocol':
        return '协议';
      case 'port':
        return '端口';
      default:
        return type;
    }
  }

  String get targetLabel {
    switch (target) {
      case 'proxy':
        return '代理';
      case 'direct':
        return '直连';
      case 'block':
        return '屏蔽';
      default:
        return target;
    }
  }

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
