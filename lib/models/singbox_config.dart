import 'dart:convert';

// ==================== Root Config ====================

class SingBoxConfig {
  final String logLevel;
  final List<Inbound> inbounds;
  final List<Outbound> outbounds;
  final RouteConfig route;
  final DnsConfig dns;
  final ExperimentalConfig experimental;

  SingBoxConfig({
    this.logLevel = 'info',
    required this.inbounds,
    required this.outbounds,
    required this.route,
    required this.dns,
    required this.experimental,
  });

  Map<String, dynamic> toJson() => {
        'log': {'level': logLevel},
        'inbounds': inbounds.map((e) => e.toJson()).toList(),
        'outbounds': outbounds.map((e) => e.toJson()).toList(),
        'route': route.toJson(),
        'dns': dns.toJson(),
        'experimental': experimental.toJson(),
      };

  static SingBoxConfig fromJson(Map<String, dynamic> json) {
    return SingBoxConfig(
      logLevel: json['log']?['level'] ?? 'info',
      inbounds: (json['inbounds'] as List?)
              ?.map((e) => Inbound.fromJson(e))
              .toList() ??
          [],
      outbounds: (json['outbounds'] as List?)
              ?.map((e) => Outbound.fromJson(e))
              .toList() ??
          [],
      route: RouteConfig.fromJson(json['route'] ?? {}),
      dns: DnsConfig.fromJson(json['dns'] ?? {}),
      experimental: ExperimentalConfig.fromJson(json['experimental'] ?? {}),
    );
  }
}

// ==================== Inbounds (Listening) ====================

class Inbound {
  final String type; // mixed, socks, http, shadowsocks, vmess, trojan, naive, hysteria, tuic
  final String tag;
  final String? listen;
  final int? listenPort;
  final Map<String, dynamic>? users; // For simple auth
  final Map<String, dynamic>? options; // Protocol specific options

  Inbound({
    required this.type,
    required this.tag,
    this.listen,
    this.listenPort,
    this.users,
    this.options,
  });

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'type': type, 'tag': tag};
    if (listen != null) map['listen'] = listen;
    if (listenPort != null) map['listen_port'] = listenPort;
    if (users != null) map['users'] = users;
    if (options != null) map.addAll(options!);
    return map;
  }

  static Inbound fromJson(Map<String, dynamic> json) {
    return Inbound(
      type: json['type'],
      tag: json['tag'],
      listen: json['listen'],
      listenPort: json['listen_port'],
      users: json['users'],
      options: json..removeWhere((k, v) => ['type', 'tag', 'listen', 'listen_port', 'users'].contains(k)),
    );
  }
}

// ==================== Outbounds (Protocols) ====================

class Outbound {
  final String type;
  final String tag;
  final String? server;
  final int? serverPort;
  
  // Protocol Specific Fields
  final String? uuid;
  final String? flow;
  final String? security;
  final String? password;
  final String? serviceName;
  
  // TLS / Reality
  final TlsConfig? tls;
  final RealityConfig? reality;
  
  // Transport (WS, HTTP, GRPC, QUIC)
  final TransportConfig? transport;
  
  // Hysteria / TUIC specific
  final String? upMbps;
  final String? downMbps;
  final String? obfsPassword;
  final String? congestionControl;

  Outbound({
    required this.type,
    required this.tag,
    this.server,
    this.serverPort,
    this.uuid,
    this.flow,
    this.security,
    this.password,
    this.serviceName,
    this.tls,
    this.reality,
    this.transport,
    this.upMbps,
    this.downMbps,
    this.obfsPassword,
    this.congestionControl,
  });

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'type': type, 'tag': tag};
    if (server != null) map['server'] = server;
    if (serverPort != null) map['server_port'] = serverPort;
    
    if (uuid != null) map['uuid'] = uuid;
    if (flow != null) map['flow'] = flow;
    if (password != null) map['password'] = password;
    
    if (tls != null) map['tls'] = tls!.toJson();
    if (reality != null) map['reality'] = reality!.toJson();
    if (transport != null) map['transport'] = transport!.toJson();
    
    // Hysteria/TUIC
    if (upMbps != null) map['up_mbps'] = upMbps;
    if (downMbps != null) map['down_mbps'] = downMbps;
    if (obfsPassword != null) map['obfs_password'] = obfsPassword;
    if (congestionControl != null) map['congestion_control'] = congestionControl;

    return map;
  }

  static Outbound fromJson(Map<String, dynamic> json) {
    return Outbound(
      type: json['type'],
      tag: json['tag'],
      server: json['server'],
      serverPort: json['server_port'],
      uuid: json['uuid'],
      flow: json['flow'],
      password: json['password'],
      tls: json['tls'] != null ? TlsConfig.fromJson(json['tls']) : null,
      reality: json['reality'] != null ? RealityConfig.fromJson(json['reality']) : null,
      transport: json['transport'] != null ? TransportConfig.fromJson(json['transport']) : null,
      upMbps: json['up_mbps'],
      downMbps: json['down_mbps'],
      obfsPassword: json['obfs_password'],
      congestionControl: json['congestion_control'],
    );
  }
}

// ==================== TLS & Reality ====================

class TlsConfig {
  final bool enabled;
  final String? serverName;
  final bool insecure;
  final String? alpn;
  final String? utls; // uTLS fingerprint

  TlsConfig({
    this.enabled = true,
    this.serverName,
    this.insecure = false,
    this.alpn,
    this.utls,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (serverName != null) 'server_name': serverName,
        'insecure': insecure,
        if (alpn != null) 'alpn': alpn,
        if (utls != null) 'utls': {'fingerprint': utls},
      };
      
  static TlsConfig fromJson(Map<String, dynamic> json) {
    return TlsConfig(
      enabled: json['enabled'] ?? false,
      serverName: json['server_name'],
      insecure: json['insecure'] ?? false,
      utls: json['utls']?['fingerprint'],
    );
  }
}

class RealityConfig {
  final bool enabled;
  final String? publicKey;
  final String? shortId;

  RealityConfig({required this.enabled, this.publicKey, this.shortId});

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (publicKey != null) 'public_key': publicKey,
        if (shortId != null) 'short_id': shortId,
      };
      
  static RealityConfig fromJson(Map<String, dynamic> json) {
    return RealityConfig(
      enabled: json['enabled'] ?? false,
      publicKey: json['public_key'],
      shortId: json['short_id'],
    );
  }
}

// ==================== Transport (WS, gRPC, HTTP) ====================

class TransportConfig {
  final String type; // ws, http, grpc, quic
  final String? path;
  final String? serviceName; // for gRPC
  final Map<String, dynamic>? headers;

  TransportConfig({required this.type, this.path, this.serviceName, this.headers});

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'type': type};
    if (path != null) map['path'] = path;
    if (serviceName != null) map['service_name'] = serviceName;
    if (headers != null) map['headers'] = headers;
    return map;
  }
  
  static TransportConfig fromJson(Map<String, dynamic> json) {
    return TransportConfig(
      type: json['type'],
      path: json['path'],
      serviceName: json['service_name'],
      headers: json['headers'],
    );
  }
}

// ==================== Routing ====================

class RouteConfig {
  final String? autoDetectInterface;
  final List<RuleConfig> rules;
  final List<GeoSiteEntry> geosite;
  final List<GeoIpEntry> geoip;

  RouteConfig({
    this.autoDetectInterface,
    required this.rules,
    required this.geosite,
    required this.geoip,
  });

  Map<String, dynamic> toJson() => {
        if (autoDetectInterface != null) 'auto_detect_interface': autoDetectInterface,
        'rules': rules.map((e) => e.toJson()).toList(),
        'geosite': geosite.map((e) => e.toJson()).toList(),
        'geoip': geoip.map((e) => e.toJson()).toList(),
      };

  static RouteConfig fromJson(Map<String, dynamic> json) {
    return RouteConfig(
      autoDetectInterface: json['auto_detect_interface'],
      rules: (json['rules'] as List?)?.map((e) => RuleConfig.fromJson(e)).toList() ?? [],
      geosite: (json['geosite'] as List?)?.map((e) => GeoSiteEntry.fromJson(e)).toList() ?? [],
      geoip: (json['geoip'] as List?)?.map((e) => GeoIpEntry.fromJson(e)).toList() ?? [],
    );
  }
}

class RuleConfig {
  final String outbound;
  final List<String>? domain;
  final List<String>? domainSuffix;
  final List<String>? ipCidr;
  final String? protocol;
  final int? sourcePort;
  final String? inbound;

  RuleConfig({
    required this.outbound,
    this.domain,
    this.domainSuffix,
    this.ipCidr,
    this.protocol,
    this.sourcePort,
    this.inbound,
  });

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'outbound': outbound};
    if (domain != null) map['domain'] = domain;
    if (domainSuffix != null) map['domain_suffix'] = domainSuffix;
    if (ipCidr != null) map['ip_cidr'] = ipCidr;
    if (protocol != null) map['protocol'] = protocol;
    if (sourcePort != null) map['source_port'] = sourcePort;
    if (inbound != null) map['inbound'] = inbound;
    return map;
  }

  static RuleConfig fromJson(Map<String, dynamic> json) {
    return RuleConfig(
      outbound: json['outbound'],
      domain: (json['domain'] as List?)?.cast<String>(),
      domainSuffix: (json['domain_suffix'] as List?)?.cast<String>(),
      ipCidr: (json['ip_cidr'] as List?)?.cast<String>(),
      protocol: json['protocol'],
      sourcePort: json['source_port'],
      inbound: json['inbound'],
    );
  }
}

class GeoSiteEntry {
  final String tag;
  final String url;
  final String? downloadDetour;

  GeoSiteEntry({required this.tag, required this.url, this.downloadDetour});
  Map<String, dynamic> toJson() => {'tag': tag, 'url': url, if(downloadDetour!=null) 'download_detour': downloadDetour};
  static GeoSiteEntry fromJson(Map<String, dynamic> json) => GeoSiteEntry(tag: json['tag'], url: json['url'], downloadDetour: json['download_detour']);
}

class GeoIpEntry {
  final String tag;
  final String url;
  final String? downloadDetour;

  GeoIpEntry({required this.tag, required this.url, this.downloadDetour});
  Map<String, dynamic> toJson() => {'tag': tag, 'url': url, if(downloadDetour!=null) 'download_detour': downloadDetour};
  static GeoIpEntry fromJson(Map<String, dynamic> json) => GeoIpEntry(tag: json['tag'], url: json['url'], downloadDetour: json['download_detour']);
}

// ==================== DNS ====================

class DnsConfig {
  final List<DnsServer> servers;
  final List<DnsRule> rules;
  final String? finalServer;
  final bool disableCache;
  final bool disableExpire;
  final bool independentCache;
  final ClientDns? client;

  DnsConfig({
    required this.servers,
    required this.rules,
    this.finalServer,
    this.disableCache = false,
    this.disableExpire = false,
    this.independentCache = false,
    this.client,
  });

  Map<String, dynamic> toJson() => {
        'servers': servers.map((e) => e.toJson()).toList(),
        'rules': rules.map((e) => e.toJson()).toList(),
        if (finalServer != null) 'final': finalServer,
        'disable_cache': disableCache,
        'disable_expire': disableExpire,
        'independent_cache': independentCache,
        if (client != null) 'client': client!.toJson(),
      };

  static DnsConfig fromJson(Map<String, dynamic> json) {
    return DnsConfig(
      servers: (json['servers'] as List?)?.map((e) => DnsServer.fromJson(e)).toList() ?? [],
      rules: (json['rules'] as List?)?.map((e) => DnsRule.fromJson(e)).toList() ?? [],
      finalServer: json['final'],
      disableCache: json['disable_cache'] ?? false,
      disableExpire: json['disable_expire'] ?? false,
      independentCache: json['independent_cache'] ?? false,
      client: json['client'] != null ? ClientDns.fromJson(json['client']) : null,
    );
  }
}

class DnsServer {
  final String tag;
  final String address;
  final String? addressResolver;
  final String? addressStrategy;
  final String? strategy;
  final DetourConfig? detour;

  DnsServer({
    required this.tag,
    required this.address,
    this.addressResolver,
    this.addressStrategy,
    this.strategy,
    this.detour,
  });

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'address': address,
        if (addressResolver != null) 'address_resolver': addressResolver,
        if (strategy != null) 'strategy': strategy,
        if (detour != null) 'detour': detour!.toJson(),
      };
      
  static DnsServer fromJson(Map<String, dynamic> json) {
    return DnsServer(
      tag: json['tag'],
      address: json['address'],
      addressResolver: json['address_resolver'],
      strategy: json['strategy'],
      detour: json['detour'] != null ? DetourConfig.fromJson(json['detour']) : null,
    );
  }
}

class DnsRule {
  final String server;
  final List<String>? domain;
  final List<String>? domainSuffix;
  final List<String>? ipCidr;
  final String? outbound;
  final String? protocol;
  final String? type; // A, AAAA, etc.

  DnsRule({
    required this.server,
    this.domain,
    this.domainSuffix,
    this.ipCidr,
    this.outbound,
    this.protocol,
    this.type,
  });

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'server': server};
    if (domain != null) map['domain'] = domain;
    if (domainSuffix != null) map['domain_suffix'] = domainSuffix;
    if (ipCidr != null) map['ip_cidr'] = ipCidr;
    if (outbound != null) map['outbound'] = outbound;
    if (protocol != null) map['protocol'] = protocol;
    if (type != null) map['type'] = type;
    return map;
  }
  
  static DnsRule fromJson(Map<String, dynamic> json) {
    return DnsRule(
      server: json['server'],
      domain: (json['domain'] as List?)?.cast<String>(),
      domainSuffix: (json['domain_suffix'] as List?)?.cast<String>(),
      ipCidr: (json['ip_cidr'] as List?)?.cast<String>(),
      outbound: json['outbound'],
      protocol: json['protocol'],
      type: json['type'],
    );
  }
}

class ClientDns {
  final String? strategy;
  final bool disableCache;
  
  ClientDns({this.strategy, this.disableCache = false});
  Map<String, dynamic> toJson() => {
    if (strategy != null) 'strategy': strategy,
    'disable_cache': disableCache,
  };
  static ClientDns fromJson(Map<String, dynamic> json) => ClientDns(
    strategy: json['strategy'],
    disableCache: json['disable_cache'] ?? false,
  );
}

class DetourConfig {
  final String outbound;
  DetourConfig({required this.outbound});
  Map<String, dynamic> toJson() => {'outbound': outbound};
  static DetourConfig fromJson(Map<String, dynamic> json) => DetourConfig(outbound: json['outbound']);
}

// ==================== Experimental (TUN) ====================

class ExperimentalConfig {
  final TunConfig? tun;
  final ClashApiConfig? clashApi;

  ExperimentalConfig({this.tun, this.clashApi});

  Map<String, dynamic> toJson() => {
        if (tun != null) 'tun': tun!.toJson(),
        if (clashApi != null) 'clash_api': clashApi!.toJson(),
      };

  static ExperimentalConfig fromJson(Map<String, dynamic> json) {
    return ExperimentalConfig(
      tun: json['tun'] != null ? TunConfig.fromJson(json['tun']) : null,
      clashApi: json['clash_api'] != null ? ClashApiConfig.fromJson(json['clash_api']) : null,
    );
  }
}

class TunConfig {
  final bool enabled;
  final String? device;
  final String stack; // system, gvisor, mixed
  final bool autoRoute;
  final bool strictRoute;
  final List<String>? includeInterface;
  final List<String>? excludeInterface;
  final List<String>? includedPackages; // Android
  final List<String>? excludedPackages; // Android

  TunConfig({
    this.enabled = false,
    this.device,
    this.stack = 'mixed',
    this.autoRoute = true,
    this.strictRoute = false,
    this.includeInterface,
    this.excludeInterface,
    this.includedPackages,
    this.excludedPackages,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (device != null) 'device': device,
        'stack': stack,
        'auto_route': autoRoute,
        'strict_route': strictRoute,
        if (includeInterface != null) 'include_interface': includeInterface,
        if (excludeInterface != null) 'exclude_interface': excludeInterface,
        if (includedPackages != null) 'included_packages': includedPackages,
        if (excludedPackages != null) 'excluded_packages': excludedPackages,
      };
      
  static TunConfig fromJson(Map<String, dynamic> json) {
    return TunConfig(
      enabled: json['enabled'] ?? false,
      device: json['device'],
      stack: json['stack'] ?? 'mixed',
      autoRoute: json['auto_route'] ?? true,
      strictRoute: json['strict_route'] ?? false,
      includeInterface: (json['include_interface'] as List?)?.cast<String>(),
      excludeInterface: (json['exclude_interface'] as List?)?.cast<String>(),
      includedPackages: (json['included_packages'] as List?)?.cast<String>(),
      excludedPackages: (json['excluded_packages'] as List?)?.cast<String>(),
    );
  }
}

class ClashApiConfig {
  final bool externalController;
  final String? externalUi;
  final String? secret;

  ClashApiConfig({
    this.externalController = false,
    this.externalUi,
    this.secret,
  });

  Map<String, dynamic> toJson() => {
        'external_controller': externalController,
        if (externalUi != null) 'external_ui': externalUi,
        if (secret != null) 'secret': secret,
      };
      
  static ClashApiConfig fromJson(Map<String, dynamic> json) {
    return ClashApiConfig(
      externalController: json['external_controller'] ?? false,
      externalUi: json['external_ui'],
      secret: json['secret'],
    );
  }
}
