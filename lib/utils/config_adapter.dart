// 配置适配器
// 将应用内部数据模型转换为各内核可识别的配置格式
// 支持 sing-box / mihomo / v2ray 三种内核配置生成

import '../models/config.dart';
import '../models/singbox_config.dart';

/// 配置适配器 — 将应用配置转换为内核配置格式
///
/// 职责：
/// - 生成 sing-box JSON 配置（inbounds / outbounds / route / DNS / TUN）
/// - 生成 mihomo YAML 兼容的 JSON 配置（proxies / rules / DNS / TUN）
/// - 生成 v2ray JSON 配置（inbounds / outbounds / routing / DNS / TUN）
/// - 将 NodeConfig 转换为各内核的出站代理格式
/// - 支持 9 种代理协议：VMess / VLESS / Trojan / Shadowsocks / Hysteria / Hysteria2 / TUIC / Naive / WireGuard
class ConfigAdapter {
  ConfigAdapter._();

  /// 构建 DNS 配置
  ///
  /// 支持四种 DNS 模式：
  /// - system：使用系统 DNS，不生成配置
  /// - custom：自定义 DNS 服务器列表
  /// - doh：DNS-over-HTTPS
  /// - dot：DNS-over-TLS
  static Map<String, dynamic> _buildDnsConfig(ProxyConfig proxyConfig) {
    final dns = proxyConfig.dnsConfig;
    if (dns.mode == DnsMode.system) return {};

    final servers = <Map<String, dynamic>>[];
    final fallback = <Map<String, dynamic>>[];

    switch (dns.mode) {
      case DnsMode.system:
        break;
      case DnsMode.custom:
        for (final s in dns.servers) {
          servers.add({'address': s, 'tag': 'remote_${s.replaceAll('.', '_')}'});
        }
        for (final s in dns.fallbackServers) {
          fallback.add({'address': s, 'tag': 'local_${s.replaceAll('.', '_')}'});
        }
      case DnsMode.doh:
        servers.add({'address': dns.dohUrl, 'tag': 'remote_doh'});
        for (final s in dns.fallbackServers) {
          fallback.add({'address': s, 'tag': 'local_${s.replaceAll('.', '_')}'});
        }
      case DnsMode.dot:
        servers.add({'address': 'tls://${dns.dotServer}', 'tag': 'remote_dot'});
        for (final s in dns.fallbackServers) {
          fallback.add({'address': s, 'tag': 'local_${s.replaceAll('.', '_')}'});
        }
    }

    return {
      'dns': {
        'servers': [...servers, ...fallback],
        'rules': [
          {
            'outbound': 'any',
            'server': fallback.isNotEmpty ? fallback.first['tag'] : 'local',
          },
        ],
        'strategy': dns.remoteResolve ? 'prefer_ipv4' : 'ipv4_only',
        'independent_cache': true,
      },
    };
  }

  /// 生成 sing-box 内核配置
  ///
  /// 配置结构：
  /// - inbounds：SOCKS + HTTP 入站，TUN 模式时追加 TUN 入站
  /// - outbounds：代理出站 + urltest 自动选择 + direct/block/dns
  /// - route：路由规则（广告屏蔽 + 用户自定义规则）
  /// - experimental：Clash API + TUN 配置
  /// - dns：DNS 服务器配置
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

    final rules = <SingboxRouteRule>[];

    if (proxyConfig.adBlocking) {
      rules.add(const SingboxRouteRule(
        outbound: 'block',
        domain: [],
        ip: [],
        geosite: ['category-ads-all'],
      ));
    }

    for (final r in routingRules.where((r) => r.enabled)) {
      rules.add(SingboxRouteRule(
        outbound: r.target,
        domain: r.type == 'domain' ? [r.match] : [],
        domainKeyword: r.type == 'domain_keyword' ? [r.match] : [],
        domainSuffix: r.type == 'domain_suffix' ? [r.match] : [],
        ip: r.type == 'ip_cidr' ? [r.match] : [],
        geoip: r.type == 'geoip' ? [r.match] : [],
        geosite: r.type == 'geosite' ? [r.match] : [],
        process: r.type == 'process' ? [r.match] : [],
        protocol: r.type == 'protocol' ? [r.match] : [],
        port: r.type == 'port' ? [int.tryParse(r.match) ?? 0] : [],
      ));
    }

    final clashApi = {
      'clash_api': {
        'external_controller': proxyConfig.lanSharing
            ? '0.0.0.0:9090'
            : '127.0.0.1:9090',
        'secret': '',
      },
    };

    final experimental = <String, dynamic>{...clashApi};
    if (proxyConfig.tunEnabled) {
      experimental['tun'] = {
        'stack': 'system',
        'auto_route': true,
        'strict_route': true,
      };
    }

    final listenAddr =
        proxyConfig.lanSharing ? '0.0.0.0' : proxyConfig.localAddress;

    final result = SingboxConfig(
      inbounds: [
        SingboxInbound(
          type: 'socks',
          tag: 'socks-in',
          listenAddress: listenAddr,
          listenPort: proxyConfig.socksPort,
        ),
        SingboxInbound(
          type: 'http',
          tag: 'http-in',
          listenAddress: listenAddr,
          listenPort: proxyConfig.httpPort,
        ),
        if (proxyConfig.tunEnabled)
          const SingboxInbound(
            type: 'tun',
            tag: 'tun-in',
            extra: {
              'stack': 'system',
              'auto_route': true,
              'strict_route': true,
            },
          ),
      ],
      outbounds: outbounds,
      route: SingboxRoute(
        rules: rules,
        finalOutbound: activeNode != null ? 'auto' : 'direct',
      ),
      experimental: experimental,
    ).toJson();

    result.addAll(_buildDnsConfig(proxyConfig));

    return result;
  }

  /// 将 NodeConfig 转换为 sing-box 出站代理格式
  ///
  /// 支持 9 种协议：VMess / VLESS / Trojan / Shadowsocks /
  /// Hysteria / Hysteria2 / TUIC / Naive / WireGuard
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
              'enabled':
                  extra['security'] == 'tls' || extra['security'] == 'reality',
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

  /// 生成 mihomo 内核配置
  ///
  /// 配置结构：
  /// - mixed-port / socks-port / port：代理端口
  /// - tun：TUN 模式配置
  /// - proxies：代理节点列表
  /// - proxy-groups：代理组（PROXY 选择组）
  /// - rules：路由规则（广告屏蔽 + 用户自定义规则 + MATCH 兜底）
  /// - dns：DNS 配置（fake-ip 模式）
  static Map<String, dynamic> toMihomoConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) {
    final proxies = <Map<String, dynamic>>[];

    if (activeNode != null) {
      proxies.add(_nodeToMihomoProxy(activeNode));
    }

    final rules = <String>[];

    if (proxyConfig.adBlocking) {
      rules.add('DOMAIN-KEYWORD,ads,BLOCK');
      rules.add('GEOSITE,category-ads-all,BLOCK');
    }

    for (final r in routingRules.where((r) => r.enabled)) {
      switch (r.type) {
        case 'domain':
          rules.add('DOMAIN,${r.match},${r.target.toUpperCase()}');
        case 'domain_keyword':
          rules.add('DOMAIN-KEYWORD,${r.match},${r.target.toUpperCase()}');
        case 'domain_suffix':
          rules.add('DOMAIN-SUFFIX,${r.match},${r.target.toUpperCase()}');
        case 'ip_cidr':
          rules.add('IP-CIDR,${r.match},${r.target.toUpperCase()}');
        case 'geoip':
          rules.add('GEOIP,${r.match},${r.target.toUpperCase()}');
        case 'geosite':
          rules.add('GEOSITE,${r.match},${r.target.toUpperCase()}');
        case 'process':
          rules.add('PROCESS-NAME,${r.match},${r.target.toUpperCase()}');
        case 'port':
          rules.add('DST-PORT,${r.match},${r.target.toUpperCase()}');
        default:
          rules.add('MATCH,${r.target.toUpperCase()}');
      }
    }

    rules.add('MATCH,${activeNode != null ? "PROXY" : "DIRECT"}');

    final dnsConfig = <String, dynamic>{};
    if (proxyConfig.dnsConfig.mode != DnsMode.system) {
      dnsConfig['dns'] = {
        'enable': true,
        'listen': '0.0.0.0:1053',
        'enhanced-mode': 'fake-ip',
        'nameserver': proxyConfig.dnsConfig.servers,
        'fallback': proxyConfig.dnsConfig.fallbackServers,
      };
    }

    return {
      'mixed-port': proxyConfig.localPort,
      'socks-port': proxyConfig.socksPort,
      'port': proxyConfig.httpPort,
      'allow-lan': proxyConfig.lanSharing,
      'bind-address': proxyConfig.lanSharing ? '*' : '127.0.0.1',
      'mode': 'rule',
      'log-level': 'info',
      if (proxyConfig.tunEnabled)
        'tun': {
          'enable': true,
          'stack': 'system',
          'auto-route': true,
          'auto-detect-interface': true,
        },
      if (proxies.isNotEmpty) 'proxies': proxies,
      'proxy-groups': [
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies':
              activeNode != null ? [activeNode.name] : ['DIRECT'],
        },
      ],
      'rules': rules,
      ...dnsConfig,
    };
  }

  /// 将 NodeConfig 转换为 mihomo 代理格式
  ///
  /// 支持 VMess / VLESS / Trojan / Shadowsocks / Hysteria2
  /// 其他协议降级为 socks5
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

  /// 生成 v2ray 内核配置
  ///
  /// 配置结构：
  /// - inbounds：SOCKS + HTTP 入站，TUN 模式时追加 dokodemo-door
  /// - outbounds：代理出站 + direct + block
  /// - routing：路由规则（广告屏蔽 + 用户自定义规则）
  /// - dns：DNS 服务器配置
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

    final rules = <Map<String, dynamic>>[];

    if (proxyConfig.adBlocking) {
      rules.add({
        'type': 'field',
        'domain': ['geosite:category-ads-all'],
        'outboundTag': 'block',
      });
    }

    for (final r in routingRules.where((r) => r.enabled)) {
      switch (r.type) {
        case 'domain':
          rules.add({
            'type': 'field',
            'domain': [r.match],
            'outboundTag': r.target,
          });
        case 'domain_keyword':
          rules.add({
            'type': 'field',
            'domain': ['keyword:${r.match}'],
            'outboundTag': r.target,
          });
        case 'domain_suffix':
          rules.add({
            'type': 'field',
            'domain': ['domain-suffix:${r.match}'],
            'outboundTag': r.target,
          });
        case 'ip_cidr':
          rules.add({
            'type': 'field',
            'ip': [r.match],
            'outboundTag': r.target,
          });
        case 'geoip':
          rules.add({
            'type': 'field',
            'ip': ['geoip:${r.match}'],
            'outboundTag': r.target,
          });
        case 'geosite':
          rules.add({
            'type': 'field',
            'domain': ['geosite:${r.match}'],
            'outboundTag': r.target,
          });
        case 'process':
          rules.add({
            'type': 'field',
            'process': [r.match],
            'outboundTag': r.target,
          });
        case 'port':
          rules.add({
            'type': 'field',
            'port': r.match,
            'outboundTag': r.target,
          });
        default:
          rules.add({
            'type': 'field',
            'outboundTag': r.target,
          });
      }
    }

    final listenAddr =
        proxyConfig.lanSharing ? '0.0.0.0' : proxyConfig.localAddress;

    final dnsConfig = <String, dynamic>{};
    if (proxyConfig.dnsConfig.mode != DnsMode.system) {
      dnsConfig['dns'] = {
        'servers': [
          ...proxyConfig.dnsConfig.servers.map((s) => {
                'address': s,
                'skipFallback': false,
              }),
          ...proxyConfig.dnsConfig.fallbackServers.map((s) => {
                'address': s,
                'skipFallback': true,
              }),
        ],
        'queryStrategy': 'UseIP',
      };
    }

    return {
      'log': {'loglevel': 'info'},
      'inbounds': [
        {
          'tag': 'socks',
          'protocol': 'socks',
          'listen': listenAddr,
          'port': proxyConfig.socksPort,
        },
        {
          'tag': 'http',
          'protocol': 'http',
          'listen': listenAddr,
          'port': proxyConfig.httpPort,
        },
        if (proxyConfig.tunEnabled)
          {
            'tag': 'tun',
            'protocol': 'dokodemo-door',
            'listen': '0.0.0.0',
            'port': 0,
            'settings': {
              'network': 'tcp,udp',
              'followRedirect': true,
            },
            'streamSettings': {
              'sockopt': {
                'tproxy': 'tun',
              },
            },
          },
      ],
      'outbounds': outbounds,
      'routing': {
        'rules': rules,
        'domainStrategy': 'IPIfNonMatch',
      },
      ...dnsConfig,
    };
  }

  /// 将 NodeConfig 转换为 v2ray 出站代理格式
  ///
  /// 支持 VMess / VLESS / Trojan / Shadowsocks
  /// 其他协议降级为 socks
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
