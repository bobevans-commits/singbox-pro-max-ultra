import '../models/config.dart';
import '../models/singbox_config.dart';

class ConfigAdapter {
  ConfigAdapter._();

  static Map<String, dynamic> toSingboxConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) {
    final config = SingboxConfig.defaultConfig(
      socksPort: proxyConfig.socksPort,
      httpPort: proxyConfig.httpPort,
    );

    final outbounds = <SingboxOutbound>[];

    if (activeNode != null) {
      final proxyOutbound = _nodeToSingboxOutbound(activeNode);
      outbounds.add(proxyOutbound);
      outbounds.add(const SingboxOutbound(
        type: 'urltest',
        tag: 'auto',
        options: {
          'outbounds': ['proxy'],
          'url': 'https://www.gstatic.com/generate_204',
          'interval': '5m',
        },
      ));
    }

    outbounds.addAll(config.outbounds);

    final rules = routingRules
        .where((r) => r.enabled)
        .map((r) => SingboxRouteRule(
              outbound: r.target,
              domain: r.type == 'domain' ? [r.match] : [],
              ip: r.type == 'ip' ? [r.match] : [],
            ))
        .toList();

    final clashApi = {
      'clash_api': {
        'external_controller': '127.0.0.1:9090',
        'secret': '',
      },
    };

    return SingboxConfig(
      inbounds: config.inbounds,
      outbounds: outbounds,
      route: SingboxRoute(
        rules: rules,
        finalOutbound: activeNode != null ? 'auto' : 'direct',
      ),
      experimental: proxyConfig.tunEnabled
          ? {
              ...clashApi,
              'tun': {
                'stack': 'system',
                'auto_route': true,
                'strict_route': true,
              },
            }
          : clashApi,
    ).toJson();
  }

  static SingboxOutbound _nodeToSingboxOutbound(NodeConfig node) {
    final extra = Map<String, dynamic>.from(node.extra);

    switch (node.protocol) {
      case ProxyProtocol.vmess:
        return SingboxOutbound(
          type: 'vmess',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'uuid': extra['uuid'] ?? '',
            'alter_id': extra['alterId'] ?? 0,
            'security': extra['security'] ?? 'auto',
            if (extra['network'] == 'ws')
              'transport': {
                'type': 'ws',
                'path': extra['wsPath'] ?? '/',
                if (extra['wsHost'] != null)
                  'headers': {'Host': extra['wsHost']},
              },
          },
        );

      case ProxyProtocol.vless:
        return SingboxOutbound(
          type: 'vless',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'uuid': extra['uuid'] ?? '',
            'flow': extra['flow'] ?? '',
            'tls': {
              'enabled': extra['security'] == 'tls' || extra['security'] == 'reality',
              'server_name': extra['sni'] ?? node.address,
              'insecure': extra['insecure'] == true,
              if (extra['security'] == 'reality') ...{
                'reality': {
                  'enabled': true,
                  'public_key': extra['publicKey'] ?? '',
                  'short_id': extra['shortId'] ?? '',
                },
              },
            },
            if (extra['type'] == 'ws')
              'transport': {
                'type': 'ws',
                'path': extra['wsPath'] ?? '/',
              },
          },
        );

      case ProxyProtocol.trojan:
        return SingboxOutbound(
          type: 'trojan',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'password': extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              'insecure': extra['insecure'] == true,
            },
          },
        );

      case ProxyProtocol.shadowsocks:
        return SingboxOutbound(
          type: 'shadowsocks',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'method': extra['method'] ?? 'aes-256-gcm',
            'password': extra['password'] ?? '',
          },
        );

      case ProxyProtocol.hysteria2:
        return SingboxOutbound(
          type: 'hysteria2',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'password': extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              'insecure': extra['insecure'] == true,
            },
          },
        );

      case ProxyProtocol.hysteria:
        return SingboxOutbound(
          type: 'hysteria',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'auth': extra['auth'] ?? extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              'insecure': extra['insecure'] == true,
            },
          },
        );

      case ProxyProtocol.tuic:
        return SingboxOutbound(
          type: 'tuic',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'uuid': extra['uuid'] ?? '',
            'password': extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              'alpn': ['h3'],
            },
          },
        );

      case ProxyProtocol.naive:
        return SingboxOutbound(
          type: 'naive',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'username': extra['username'] ?? '',
            'password': extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
            },
          },
        );

      case ProxyProtocol.wireguard:
        final localAddress = extra['localAddress'];
        final localAddressList = localAddress is String
            ? [localAddress]
            : (localAddress as List?)?.cast<String>() ?? [];
        return SingboxOutbound(
          type: 'wireguard',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'private_key': extra['privateKey'] ?? '',
            'peer_public_key': extra['peerPublicKey'] ?? '',
            'local_address': localAddressList,
          },
        );
    }
  }

  static Map<String, dynamic> toMihomoConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) {
    final proxies = <Map<String, dynamic>>[];

    if (activeNode != null) {
      proxies.add(_nodeToMihomoProxy(activeNode));
    }

    final rules = routingRules
        .where((r) => r.enabled)
        .map((r) {
          switch (r.type) {
            case 'domain':
              return 'DOMAIN,${r.match},${r.target.toUpperCase()}';
            case 'ip':
              return 'IP-CIDR,${r.match}/32,${r.target.toUpperCase()}';
            default:
              return 'MATCH,${r.target.toUpperCase()}';
          }
        })
        .toList();

    rules.add('MATCH,${activeNode != null ? "PROXY" : "DIRECT"}');

    return {
      'mixed-port': proxyConfig.localPort,
      'socks-port': proxyConfig.socksPort,
      'port': proxyConfig.httpPort,
      'allow-lan': false,
      'mode': 'rule',
      'log-level': 'info',
      if (proxies.isNotEmpty) 'proxies': proxies,
      'proxy-groups': [
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': activeNode != null ? [activeNode.name] : ['DIRECT'],
        },
      ],
      'rules': rules,
    };
  }

  static Map<String, dynamic> _nodeToMihomoProxy(NodeConfig node) {
    final extra = Map<String, dynamic>.from(node.extra);

    switch (node.protocol) {
      case ProxyProtocol.vmess:
        return {
          'name': node.name,
          'type': 'vmess',
          'server': node.address,
          'port': node.port,
          'uuid': extra['uuid'] ?? '',
          'alterId': extra['alterId'] ?? 0,
          'cipher': extra['security'] ?? 'auto',
          'network': extra['network'] ?? 'tcp',
        };
      case ProxyProtocol.vless:
        return {
          'name': node.name,
          'type': 'vless',
          'server': node.address,
          'port': node.port,
          'uuid': extra['uuid'] ?? '',
          'flow': extra['flow'] ?? '',
          'network': extra['type'] ?? 'tcp',
          'tls': true,
          'servername': extra['sni'] ?? node.address,
        };
      case ProxyProtocol.trojan:
        return {
          'name': node.name,
          'type': 'trojan',
          'server': node.address,
          'port': node.port,
          'password': extra['password'] ?? '',
          'sni': extra['sni'] ?? node.address,
        };
      case ProxyProtocol.shadowsocks:
        return {
          'name': node.name,
          'type': 'ss',
          'server': node.address,
          'port': node.port,
          'cipher': extra['method'] ?? 'aes-256-gcm',
          'password': extra['password'] ?? '',
        };
      case ProxyProtocol.hysteria2:
        return {
          'name': node.name,
          'type': 'hysteria2',
          'server': node.address,
          'port': node.port,
          'password': extra['password'] ?? '',
          'sni': extra['sni'] ?? node.address,
        };
      default:
        return {
          'name': node.name,
          'type': 'socks5',
          'server': node.address,
          'port': node.port,
        };
    }
  }

  static Map<String, dynamic> toV2rayConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) {
    final outbounds = <Map<String, dynamic>>[
      {'tag': 'direct', 'protocol': 'freedom'},
      {'tag': 'block', 'protocol': 'blackhole'},
    ];

    if (activeNode != null) {
      outbounds.insert(0, _nodeToV2rayOutbound(activeNode));
    }

    final rules = routingRules.where((r) => r.enabled).map((r) {
      switch (r.type) {
        case 'domain':
          return {
            'type': 'field',
            'domain': [r.match],
            'outboundTag': r.target,
          };
        case 'ip':
          return {
            'type': 'field',
            'ip': [r.match],
            'outboundTag': r.target,
          };
        default:
          return {
            'type': 'field',
            'outboundTag': r.target,
          };
      }
    }).toList();

    return {
      'log': {'loglevel': 'info'},
      'inbounds': [
        {
          'tag': 'socks',
          'protocol': 'socks',
          'listen': '127.0.0.1',
          'port': proxyConfig.socksPort,
        },
        {
          'tag': 'http',
          'protocol': 'http',
          'listen': '127.0.0.1',
          'port': proxyConfig.httpPort,
        },
      ],
      'outbounds': outbounds,
      'routing': {
        'rules': rules,
        'domainStrategy': 'IPIfNonMatch',
      },
    };
  }

  static Map<String, dynamic> _nodeToV2rayOutbound(NodeConfig node) {
    final extra = Map<String, dynamic>.from(node.extra);

    switch (node.protocol) {
      case ProxyProtocol.vmess:
        return {
          'tag': 'proxy',
          'protocol': 'vmess',
          'settings': {
            'vnext': [
              {
                'address': node.address,
                'port': node.port,
                'users': [
                  {
                    'id': extra['uuid'] ?? '',
                    'alterId': extra['alterId'] ?? 0,
                    'security': extra['security'] ?? 'auto',
                  },
                ],
              },
            ],
          },
        };
      case ProxyProtocol.vless:
        return {
          'tag': 'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': node.address,
                'port': node.port,
                'users': [
                  {
                    'id': extra['uuid'] ?? '',
                    'flow': extra['flow'] ?? '',
                    'encryption': 'none',
                  },
                ],
              },
            ],
          },
          'streamSettings': {
            'network': extra['type'] ?? 'tcp',
            'security': extra['security'] ?? 'none',
            if (extra['sni'] != null)
              'tlsSettings': {
                'serverName': extra['sni'],
              },
          },
        };
      case ProxyProtocol.trojan:
        return {
          'tag': 'proxy',
          'protocol': 'trojan',
          'settings': {
            'servers': [
              {
                'address': node.address,
                'port': node.port,
                'password': extra['password'] ?? '',
              },
            ],
          },
        };
      case ProxyProtocol.shadowsocks:
        return {
          'tag': 'proxy',
          'protocol': 'shadowsocks',
          'settings': {
            'servers': [
              {
                'address': node.address,
                'port': node.port,
                'method': extra['method'] ?? 'aes-256-gcm',
                'password': extra['password'] ?? '',
              },
            ],
          },
        };
      default:
        return {
          'tag': 'proxy',
          'protocol': 'socks',
          'settings': {
            'servers': [
              {
                'address': node.address,
                'port': node.port,
              },
            ],
          },
        };
    }
  }
}
