// 核心数据模型定义
// 定义代理客户端的所有数据结构：内核类型、代理协议、节点配置、DNS 配置、代理配置、路由规则

import 'dart:convert';

/// 内核类型枚举
///
/// 支持三种代理内核：
/// - singbox：SagerNet/sing-box，高性能通用代理平台
/// - mihomo：MetaCubeX/mihomo (Clash Meta)，兼容 Clash API
/// - v2ray：XTLS/Xray-core，支持 VLESS/XTLS 等协议
enum KernelType {
  singbox('sing-box', 'SagerNet/sing-box'),
  mihomo('mihomo', 'MetaCubeX/mihomo'),
  v2ray('v2ray', 'XTLS/Xray-core');

  /// 内核显示名称
  final String label;

  /// GitHub 仓库路径（用于下载和版本查询）
  final String repo;

  const KernelType(this.label, this.repo);

  /// 根据名称字符串查找内核类型，默认返回 singbox
  static KernelType fromName(String name) {
    return KernelType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => KernelType.singbox,
    );
  }
}

/// 内核安装状态枚举
///
/// 状态流转：notInstalled → downloading → installing → installed → running
/// 任何阶段都可能进入 error 状态
enum KernelStatus {
  /// 未安装
  notInstalled,

  /// 下载中
  downloading,

  /// 安装中（解压）
  installing,

  /// 已安装
  installed,

  /// 运行中
  running,

  /// 停止中
  stopping,

  /// 错误
  error;

  /// 状态的中文描述
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

/// 代理协议枚举
///
/// 支持 9 种主流代理协议
enum ProxyProtocol {
  /// VMess 协议（V2Ray 原生）
  vmess,

  /// VLESS 协议（轻量级，支持 XTLS）
  vless,

  /// Trojan 协议（伪装 HTTPS）
  trojan,

  /// Shadowsocks 协议
  shadowsocks,

  /// Hysteria 协议（基于 QUIC）
  hysteria,

  /// Hysteria2 协议（Hysteria 第二代）
  hysteria2,

  /// TUIC 协议（基于 QUIC 的代理）
  tuic,

  /// Naive 协议（基于 HTTPS 的代理）
  naive,

  /// WireGuard 协议（VPN 隧道）
  wireguard;

  /// 协议的显示名称
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

  /// 根据字符串查找协议类型，默认返回 VMess
  static ProxyProtocol fromString(String s) {
    return ProxyProtocol.values.firstWhere(
      (e) => e.name.toLowerCase() == s.toLowerCase(),
      orElse: () => ProxyProtocol.vmess,
    );
  }
}

/// 节点配置数据模型
///
/// 表示一个代理服务器节点，包含连接所需的所有信息
/// 以及测速结果（延迟、下载速度）
class NodeConfig {
  /// 节点唯一标识
  final String id;

  /// 节点名称（显示用）
  final String name;

  /// 代理协议类型
  final ProxyProtocol protocol;

  /// 服务器地址（域名或 IP）
  final String address;

  /// 服务器端口
  final int port;

  /// 协议特定参数（如 UUID、密码、加密方式等）
  final Map<String, dynamic> extra;

  /// 延迟（毫秒），null 表示未测速，-1 表示超时
  int? latencyMs;

  /// 下载速度（字节/秒），null 表示未测速
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

  /// 序列化为 JSON（不包含测速结果）
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'address': address,
        'port': port,
        'extra': extra,
      };

  /// 从 JSON 反序列化
  factory NodeConfig.fromJson(Map<String, dynamic> json) => NodeConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol: ProxyProtocol.fromString(json['protocol'] as String),
        address: json['address'] as String,
        port: json['port'] as int,
        extra: Map<String, dynamic>.from(json['extra'] as Map? ?? {}),
      );

  /// 序列化为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 字符串反序列化
  factory NodeConfig.fromJsonString(String s) =>
      NodeConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// DNS 模式枚举
///
/// - system：使用系统默认 DNS
/// - custom：自定义 DNS 服务器列表
/// - doh：DNS-over-HTTPS（加密 DNS 查询）
/// - dot：DNS-over-TLS（TLS 加密 DNS 查询）
enum DnsMode {
  system('system', '系统 DNS'),
  custom('custom', '自定义'),
  doh('doh', 'DNS-over-HTTPS'),
  dot('dot', 'DNS-over-TLS');

  /// 模式值（用于序列化）
  final String value;

  /// 模式显示名称
  final String label;

  const DnsMode(this.value, this.label);

  /// 根据字符串查找 DNS 模式，默认返回 system
  static DnsMode fromString(String s) {
    return DnsMode.values.firstWhere(
      (e) => e.value == s,
      orElse: () => DnsMode.system,
    );
  }
}

/// DNS 配置数据模型
///
/// 配置 DNS 解析策略，支持自定义服务器、DoH、DoT
class DnsConfig {
  /// DNS 模式
  final DnsMode mode;

  /// 主 DNS 服务器列表
  final List<String> servers;

  /// 备用 DNS 服务器列表（国内 DNS）
  final List<String> fallbackServers;

  /// 是否启用远程 DNS 解析（防 DNS 泄露）
  final bool remoteResolve;

  /// DoH URL（如 https://dns.google/dns-query）
  final String dohUrl;

  /// DoT 服务器地址（如 dns.google）
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

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'servers': servers,
        'fallback_servers': fallbackServers,
        'remote_resolve': remoteResolve,
        'doh_url': dohUrl,
        'dot_server': dotServer,
      };

  /// 从 JSON 反序列化
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

/// 代理配置数据模型
///
/// 应用的核心配置，包含代理运行所需的所有参数
class ProxyConfig {
  /// 当前使用的内核类型
  final KernelType kernelType;

  /// 本地监听地址
  final String localAddress;

  /// 本地混合代理端口
  final int localPort;

  /// SOCKS5 代理端口
  final int socksPort;

  /// HTTP 代理端口
  final int httpPort;

  /// 是否启用 TUN 模式（虚拟网卡全局代理）
  final bool tunEnabled;

  /// 是否设置系统代理
  final bool systemProxy;

  /// 是否允许局域网连接
  final bool lanSharing;

  /// 是否启用广告屏蔽
  final bool adBlocking;

  /// 是否启用智能节点选择
  final bool smartNode;

  /// 订阅自动刷新间隔（分钟），0 表示不自动刷新
  final int subRefreshMinutes;

  /// 节点列表
  final List<NodeConfig> nodes;

  /// DNS 配置
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
    this.subRefreshMinutes = 0,
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
    int? subRefreshMinutes,
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
      subRefreshMinutes: subRefreshMinutes ?? this.subRefreshMinutes,
      nodes: nodes ?? this.nodes,
      dnsConfig: dnsConfig ?? this.dnsConfig,
    );
  }

  /// 序列化为 JSON
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
        'sub_refresh_minutes': subRefreshMinutes,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'dns_config': dnsConfig.toJson(),
      };

  /// 从 JSON 反序列化
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
        subRefreshMinutes: json['sub_refresh_minutes'] as int? ?? 0,
        nodes: (json['nodes'] as List?)
                ?.map((n) => NodeConfig.fromJson(n as Map<String, dynamic>))
                .toList() ??
            [],
        dnsConfig: json['dns_config'] != null
            ? DnsConfig.fromJson(json['dns_config'] as Map<String, dynamic>)
            : const DnsConfig(),
      );
}

/// 路由规则数据模型
///
/// 定义流量分流规则，支持多种匹配类型和目标
class RoutingRule {
  /// 规则唯一标识
  final String id;

  /// 规则名称（显示用）
  final String name;

  /// 匹配类型：domain / domain_keyword / domain_suffix / ip_cidr / geoip / geosite / process / protocol / port
  final String type;

  /// 匹配值（域名、IP、GeoIP 代码等）
  final String match;

  /// 目标：proxy（代理）/ direct（直连）/ block（屏蔽）
  final String target;

  /// 是否启用
  final bool enabled;

  RoutingRule({
    required this.id,
    required this.name,
    this.type = 'domain',
    this.match = '',
    this.target = 'proxy',
    this.enabled = true,
  });

  /// 支持的匹配类型列表
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

  /// 支持的目标列表
  static const targetOptions = ['proxy', 'direct', 'block'];

  /// 预设路由规则列表
  ///
  /// 包含常用的分流规则：国内直连、广告屏蔽、Google/GitHub/Telegram 等走代理
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

  /// 预设规则私有构造函数
  const RoutingRule._preset(this.name, this.type, this.match, this.target)
      : id = '',
        enabled = true;

  /// 匹配类型的中文标签
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

  /// 目标的中文标签
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

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'match': match,
        'target': target,
        'enabled': enabled,
      };

  /// 从 JSON 反序列化
  factory RoutingRule.fromJson(Map<String, dynamic> json) => RoutingRule(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'domain',
        match: json['match'] as String? ?? '',
        target: json['target'] as String? ?? 'proxy',
        enabled: json['enabled'] as bool? ?? true,
      );
}
