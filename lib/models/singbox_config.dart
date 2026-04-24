import 'dart:convert';

class SingboxOutbound {
  final String type;
  final String tag;
  final Map<String, dynamic> options;

  const SingboxOutbound({
    required this.type,
    required this.tag,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'tag': tag,
        ...options,
      };

  factory SingboxOutbound.fromJson(Map<String, dynamic> json) => SingboxOutbound(
        type: json['type'] as String,
        tag: json['tag'] as String,
        options: Map.from(json)..remove('type')..remove('tag'),
      );
}

class SingboxRouteRule {
  final String outbound;
  final List<String> domain;
  final List<String> ip;

  const SingboxRouteRule({
    required this.outbound,
    this.domain = const [],
    this.ip = const [],
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'outbound': outbound};
    if (domain.isNotEmpty) map['domain'] = domain;
    if (ip.isNotEmpty) map['ip_cidr'] = ip;
    return map;
  }
}

class SingboxRoute {
  final List<SingboxRouteRule> rules;
  final String? finalOutbound;

  const SingboxRoute({
    this.rules = const [],
    this.finalOutbound,
  });

  Map<String, dynamic> toJson() => {
        'rules': rules.map((r) => r.toJson()).toList(),
        if (finalOutbound != null) 'final': finalOutbound,
      };
}

class SingboxInbound {
  final String type;
  final String tag;
  final String listenAddress;
  final int listenPort;
  final Map<String, dynamic> extra;

  const SingboxInbound({
    required this.type,
    required this.tag,
    this.listenAddress = '127.0.0.1',
    this.listenPort = 1080,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'tag': tag,
        'listen': listenAddress,
        'listen_port': listenPort,
        ...extra,
      };
}

class SingboxConfig {
  final List<SingboxInbound> inbounds;
  final List<SingboxOutbound> outbounds;
  final SingboxRoute route;
  final Map<String, dynamic> experimental;

  const SingboxConfig({
    this.inbounds = const [],
    this.outbounds = const [],
    this.route = const SingboxRoute(),
    this.experimental = const {},
  });

  Map<String, dynamic> toJson() => {
        'log': {
          'level': 'info',
          'timestamp': true,
        },
        if (inbounds.isNotEmpty)
          'inbounds': inbounds.map((i) => i.toJson()).toList(),
        if (outbounds.isNotEmpty)
          'outbounds': outbounds.map((o) => o.toJson()).toList(),
        'route': route.toJson(),
        if (experimental.isNotEmpty) 'experimental': experimental,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SingboxConfig.fromJson(Map<String, dynamic> json) => SingboxConfig(
        inbounds: (json['inbounds'] as List?)
                ?.map((i) => SingboxInbound.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        outbounds: (json['outbounds'] as List?)
                ?.map((o) => SingboxOutbound.fromJson(o as Map<String, dynamic>))
                .toList() ??
            [],
        route: json['route'] != null
            ? SingboxRoute(
                rules: (json['route']['rules'] as List?)
                        ?.map((r) => SingboxRouteRule(
                              outbound: r['outbound'] as String? ?? 'direct',
                              domain: (r['domain'] as List?)
                                      ?.map((d) => d as String)
                                      .toList() ??
                                  [],
                              ip: (r['ip_cidr'] as List?)
                                      ?.map((i) => i as String)
                                      .toList() ??
                                  [],
                            ))
                        .toList() ??
                    [],
                finalOutbound: json['route']['final'] as String?,
              )
            : const SingboxRoute(),
        experimental: Map<String, dynamic>.from(json['experimental'] as Map? ?? {}),
      );

  factory SingboxConfig.fromJsonString(String s) =>
      SingboxConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);

  static SingboxConfig defaultConfig({
    int socksPort = 1080,
    int httpPort = 1081,
  }) {
    return SingboxConfig(
      inbounds: [
        SingboxInbound(
          type: 'socks',
          tag: 'socks-in',
          listenPort: socksPort,
        ),
        SingboxInbound(
          type: 'http',
          tag: 'http-in',
          listenPort: httpPort,
        ),
      ],
      outbounds: [
        const SingboxOutbound(type: 'direct', tag: 'direct'),
        const SingboxOutbound(type: 'block', tag: 'block'),
        const SingboxOutbound(
          type: 'urltest',
          tag: 'auto',
          options: {
            'outbounds': ['proxy'],
            'url': 'https://www.gstatic.com/generate_204',
            'interval': '5m',
          },
        ),
      ],
      route: const SingboxRoute(
        finalOutbound: 'auto',
      ),
    );
  }
}
