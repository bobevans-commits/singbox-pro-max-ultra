import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 配置适配器 - 负责将通用配置转换为不同内核所需的格式
class ConfigAdapter {
  /// 将通用配置转换为 sing-box 格式
  static Map<String, dynamic> adaptToSingBox(Map<String, dynamic> config) {
    return {
      'log': {
        'level': config['log_level'] ?? 'info',
        'timestamp': true,
      },
      'inbounds': _adaptInboundsForSingBox(config),
      'outbounds': _adaptOutboundsForSingBox(config),
      'route': _adaptRouteForSingBox(config),
      'dns': _adaptDnsForSingBox(config),
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:9090',
          'external_ui': 'ui',
        },
        'tun': config['tun_enabled'] == true
            ? {
                'enable': true,
                'stack': 'mixed',
                'auto_route': true,
              }
            : null,
      },
    };
  }

  /// 将通用配置转换为 mihomo (Clash Meta) 格式
  static Map<String, dynamic> adaptToMihomo(Map<String, dynamic> config) {
    return {
      'port': config['http_port'] ?? 7890,
      'socks-port': config['socks_port'] ?? 7891,
      'allow-lan': false,
      'mode': 'rule',
      'log-level': config['log_level'] ?? 'info',
      'dns': _adaptDnsForMihomo(config),
      'tun': config['tun_enabled'] == true
          ? {
              'enable': true,
              'stack': 'mixed',
              'auto-route': true,
            }
          : null,
      'proxies': _adaptProxiesForMihomo(config),
      'proxy-groups': _adaptProxyGroupsForMihomo(config),
      'rules': _adaptRulesForMihomo(config),
    };
  }

  /// 将通用配置转换为 v2ray (Xray) 格式
  static Map<String, dynamic> adaptToV2Ray(Map<String, dynamic> config) {
    return {
      'log': {
        'access': '',
        'error': '',
        'loglevel': config['log_level'] ?? 'info',
      },
      'inbounds': _adaptInboundsForV2Ray(config),
      'outbounds': _adaptOutboundsForV2Ray(config),
      'routing': _adaptRoutingForV2Ray(config),
      'dns': _adaptDnsForV2Ray(config),
    };
  }

  /// 适配入站配置为 sing-box 格式
  static List<Map<String, dynamic>> _adaptInboundsForSingBox(
      Map<String, dynamic> config) {
    return [
      {
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': '127.0.0.1',
        'listen_port': config['http_port'] ?? 2080,
      },
      {
        'type': 'socks',
        'tag': 'socks-in',
        'listen': '127.0.0.1',
        'listen_port': config['socks_port'] ?? 2081,
      },
    ];
  }

  /// 适配出站配置为 sing-box 格式
  static List<Map<String, dynamic>> _adaptOutboundsForSingBox(
      Map<String, dynamic> config) {
    final outbounds = <Map<String, dynamic>>[
      {'type': 'direct', 'tag': 'direct'},
      {'type': 'block', 'tag': 'block'},
      {'type': 'dns', 'tag': 'dns-out'},
    ];

    // 添加代理节点
    final nodes = config['nodes'] as List? ?? [];
    for (var node in nodes) {
      final outbound = _convertNodeToSingBoxOutbound(node);
      if (outbound != null) {
        outbounds.add(outbound);
      }
    }

    // 添加选择器
    if (nodes.isNotEmpty) {
      final proxyTags = nodes.map((n) => n['name'] as String).toList();
      outbounds.add({
        'type': 'selector',
        'tag': 'proxy',
        'outbounds': ['direct', ...proxyTags],
      });
      outbounds.add({
        'type': 'urltest',
        'tag': 'auto',
        'outbounds': proxyTags,
        'url': 'https://www.gstatic.com/generate_204',
        'interval': '3m',
      });
    }

    return outbounds;
  }

  /// 将节点转换为 sing-box 出站配置
  static Map<String, dynamic>? _convertNodeToSingBoxOutbound(
      Map<String, dynamic> node) {
    final type = node['type'] as String;
    
    switch (type.toLowerCase()) {
      case 'vmess':
        return {
          'type': 'vmess',
          'tag': node['name'],
          'server': node['server'],
          'server_port': node['port'],
          'uuid': node['uuid'],
          'security': node['security'] ?? 'auto',
          'alter_id': node['alterId'] ?? 0,
        };
      case 'vless':
        return {
          'type': 'vless',
          'tag': node['name'],
          'server': node['server'],
          'server_port': node['port'],
          'uuid': node['uuid'],
          'flow': node['flow'] ?? '',
          'packet_encoding': node['packetEncoding'] ?? 'xudp',
        };
      case 'trojan':
        return {
          'type': 'trojan',
          'tag': node['name'],
          'server': node['server'],
          'server_port': node['port'],
          'password': node['password'],
        };
      case 'shadowsocks':
        return {
          'type': 'shadowsocks',
          'tag': node['name'],
          'server': node['server'],
          'server_port': node['port'],
          'method': node['method'],
          'password': node['password'],
        };
      default:
        debugPrint('Unsupported node type: $type');
        return null;
    }
  }

  /// 适配路由配置为 sing-box 格式
  static Map<String, dynamic> _adaptRouteForSingBox(
      Map<String, dynamic> config) {
    return {
      'auto_detect_interface': true,
      'rules': [
        {'protocol': 'dns', 'outbound': 'dns-out'},
        {'ip_cidr': ['192.168.0.0/16', '10.0.0.0/8'], 'outbound': 'direct'},
      ],
    };
  }

  /// 适配 DNS 配置为 sing-box 格式
  static Map<String, dynamic> _adaptDnsForSingBox(
      Map<String, dynamic> config) {
    return {
      'servers': [
        {'tag': 'dns-local', 'address': '223.5.5.5'},
        {'tag': 'dns-remote', 'address': 'tls://8.8.8.8'},
      ],
      'rules': [
        {'outbound': 'any', 'server': 'dns-local'},
      ],
    };
  }

  /// 适配代理配置为 mihomo 格式
  static List<Map<String, dynamic>> _adaptProxiesForMihomo(
      Map<String, dynamic> config) {
    final proxies = <Map<String, dynamic>>[];
    final nodes = config['nodes'] as List? ?? [];

    for (var node in nodes) {
      final proxy = _convertNodeToMihomoProxy(node);
      if (proxy != null) {
        proxies.add(proxy);
      }
    }

    return proxies;
  }

  /// 将节点转换为 mihomo 代理配置
  static Map<String, dynamic>? _convertNodeToMihomoProxy(
      Map<String, dynamic> node) {
    final type = node['type'] as String;
    
    switch (type.toLowerCase()) {
      case 'vmess':
        return {
          'name': node['name'],
          'type': 'vmess',
          'server': node['server'],
          'port': node['port'],
          'uuid': node['uuid'],
          'alterId': node['alterId'] ?? 0,
          'cipher': node['security'] ?? 'auto',
        };
      case 'vless':
        return {
          'name': node['name'],
          'type': 'vless',
          'server': node['server'],
          'port': node['port'],
          'uuid': node['uuid'],
          'flow': node['flow'] ?? '',
          'client-fingerprint': 'chrome',
        };
      case 'trojan':
        return {
          'name': node['name'],
          'type': 'trojan',
          'server': node['server'],
          'port': node['port'],
          'password': node['password'],
        };
      case 'shadowsocks':
        return {
          'name': node['name'],
          'type': 'ss',
          'server': node['server'],
          'port': node['port'],
          'cipher': node['method'],
          'password': node['password'],
        };
      default:
        debugPrint('Unsupported node type for mihomo: $type');
        return null;
    }
  }

  /// 适配代理组为 mihomo 格式
  static List<Map<String, dynamic>> _adaptProxyGroupsForMihomo(
      Map<String, dynamic> config) {
    final nodes = config['nodes'] as List? ?? [];
    final proxyNames = nodes.map((n) => n['name'] as String).toList();

    return [
      {
        'name': 'PROXY',
        'type': 'select',
        'proxies': ['DIRECT', ...proxyNames],
      },
      {
        'name': 'AUTO',
        'type': 'url-test',
        'proxies': proxyNames,
        'url': 'https://www.gstatic.com/generate_204',
        'interval': 300,
      },
    ];
  }

  /// 适配规则为 mihomo 格式
  static List<String> _adaptRulesForMihomo(Map<String, dynamic> config) {
    return [
      'DST-PORT,53,DIRECT',
      'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
      'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
      'GEOIP,CN,DIRECT',
      'MATCH,PROXY',
    ];
  }

  /// 适配 DNS 配置为 mihomo 格式
  static Map<String, dynamic> _adaptDnsForMihomo(Map<String, dynamic> config) {
    return {
      'enable': true,
      'listen': '0.0.0.0:53',
      'nameserver': ['223.5.5.5', '114.114.114.114'],
      'fallback': ['tls://8.8.8.8', 'tls://1.1.1.1'],
    };
  }

  /// 适配入站配置为 v2ray 格式
  static List<Map<String, dynamic>> _adaptInboundsForV2Ray(
      Map<String, dynamic> config) {
    return [
      {
        'port': config['http_port'] ?? 2080,
        'listen': '127.0.0.1',
        'protocol': 'dokodemo-door',
        'settings': {'network': 'tcp,udp', 'followRedirect': true},
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls'],
        },
      },
      {
        'port': config['socks_port'] ?? 2081,
        'listen': '127.0.0.1',
        'protocol': 'socks',
        'settings': {
          'auth': 'noauth',
          'udp': true,
        },
      },
    ];
  }

  /// 适配出站配置为 v2ray 格式
  static List<Map<String, dynamic>> _adaptOutboundsForV2Ray(
      Map<String, dynamic> config) {
    final outbounds = <Map<String, dynamic>>[
      {'protocol': 'freedom', 'tag': 'direct'},
      {'protocol': 'blackhole', 'tag': 'block'},
    ];

    // 添加代理节点
    final nodes = config['nodes'] as List? ?? [];
    for (var node in nodes) {
      final outbound = _convertNodeToV2RayOutbound(node);
      if (outbound != null) {
        outbounds.add(outbound);
      }
    }

    return outbounds;
  }

  /// 将节点转换为 v2ray 出站配置
  static Map<String, dynamic>? _convertNodeToV2RayOutbound(
      Map<String, dynamic> node) {
    final type = node['type'] as String;
    
    switch (type.toLowerCase()) {
      case 'vmess':
        return {
          'protocol': 'vmess',
          'tag': node['name'],
          'streamSettings': _getStreamSettings(node),
          'settings': {
            'vnext': [
              {
                'address': node['server'],
                'port': node['port'],
                'users': [
                  {
                    'id': node['uuid'],
                    'alterId': node['alterId'] ?? 0,
                    'security': node['security'] ?? 'auto',
                  }
                ],
              }
            ],
          },
        };
      case 'trojan':
        return {
          'protocol': 'trojan',
          'tag': node['name'],
          'streamSettings': _getStreamSettings(node),
          'settings': {
            'servers': [
              {
                'address': node['server'],
                'port': node['port'],
                'password': node['password'],
              }
            ],
          },
        };
      default:
        debugPrint('Unsupported node type for v2ray: $type');
        return null;
    }
  }

  /// 获取流设置
  static Map<String, dynamic> _getStreamSettings(Map<String, dynamic> node) {
    final network = node['network'] ?? 'tcp';
    final security = node['tls'] == true ? 'tls' : null;
    
    final settings = <String, dynamic>{
      'network': network,
    };

    if (security != null) {
      settings['security'] = security;
    }

    if (network == 'ws') {
      settings['wsSettings'] = {
        'path': node['wsPath'] ?? '/',
        'headers': node['wsHeaders'] ?? {},
      };
    } else if (network == 'grpc') {
      settings['grpcSettings'] = {
        'serviceName': node['serviceName'] ?? '',
      };
    }

    return settings;
  }

  /// 适配路由配置为 v2ray 格式
  static Map<String, dynamic> _adaptRoutingForV2Ray(
      Map<String, dynamic> config) {
    return {
      'domainStrategy': 'IPIfNonMatch',
      'rules': [
        {
          'type': 'field',
          'outboundTag': 'direct',
          'ip': ['geoip:private'],
        },
        {
          'type': 'field',
          'outboundTag': 'block',
          'protocol': ['bittorrent'],
        },
      ],
    };
  }

  /// 适配 DNS 配置为 v2ray 格式
  static Map<String, dynamic> _adaptDnsForV2Ray(Map<String, dynamic> config) {
    return {
      'hosts': {},
      'servers': [
        '223.5.5.5',
        '8.8.8.8',
      ],
    };
  }
}
