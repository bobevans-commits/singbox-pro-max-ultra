import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/config.dart';
import '../models/kernel_info.dart';
import 'kernel_downloader.dart';

/// 内核配置生成器 - 负责为不同内核生成配置文件
class KernelConfigGenerator {
  /// 为指定内核生成配置文件
  static Future<String> generateConfig({
    required KernelType kernelType,
    required Map<String, dynamic> baseConfig,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final configDir = Directory('${appDir.path}/config');
    
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    Map<String, dynamic> adaptedConfig;
    String fileExtension;
    
    switch (kernelType) {
      case KernelType.singBox:
        adaptedConfig = _adaptForSingBox(baseConfig);
        fileExtension = 'json';
        break;
      case KernelType.mihomo:
        adaptedConfig = _adaptForMihomo(baseConfig);
        fileExtension = 'yaml';
        break;
      case KernelType.v2Ray:
        adaptedConfig = _adaptForV2Ray(baseConfig);
        fileExtension = 'json';
        break;
    }

    final fileName = 'config_${kernelType.name}.$fileExtension';
    final filePath = '${configDir.path}/$fileName';
    final file = File(filePath);

    if (fileExtension == 'yaml') {
      // 使用 yaml 包需要导入，这里简单处理
      final yamlContent = _convertToYaml(adaptedConfig);
      await file.writeAsString(yamlContent);
    } else {
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(adaptedConfig));
    }

    return filePath;
  }

  /// 适配配置为 sing-box 格式
  static Map<String, dynamic> _adaptForSingBox(Map<String, dynamic> config) {
    final nodes = config['nodes'] as List<Map<String, dynamic>>? ?? [];
    
    final outbounds = <Map<String, dynamic>>[
      {'type': 'direct', 'tag': 'direct'},
      {'type': 'block', 'tag': 'block'},
      {'type': 'dns', 'tag': 'dns-out'},
    ];

    // 转换节点为 sing-box 出站配置
    for (var node in nodes) {
      final outbound = _nodeToSingBoxOutbound(node);
      if (outbound != null) {
        outbounds.add(outbound);
      }
    }

    // 添加选择器和自动测试组
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

    return {
      'log': {
        'level': config['log_level'] ?? 'info',
        'timestamp': true,
      },
      'inbounds': [
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
      ],
      'outbounds': outbounds,
      'route': {
        'auto_detect_interface': true,
        'rules': [
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {'ip_cidr': ['192.168.0.0/16', '10.0.0.0/8'], 'outbound': 'direct'},
        ],
      },
      'dns': {
        'servers': [
          {'tag': 'dns-local', 'address': '223.5.5.5'},
          {'tag': 'dns-remote', 'address': 'tls://8.8.8.8'},
        ],
        'rules': [
          {'outbound': 'any', 'server': 'dns-local'},
        ],
      },
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:9090',
          'external_ui': 'ui',
        },
      },
    };
  }

  /// 将节点转换为 sing-box 出站配置
  static Map<String, dynamic>? _nodeToSingBoxOutbound(Map<String, dynamic> node) {
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
      case 'hysteria':
      case 'hysteria2':
        return {
          'type': 'hysteria2',
          'tag': node['name'],
          'server': node['server'],
          'server_port': node['port'],
          'password': node['password'],
        };
      case 'tuic':
        return {
          'type': 'tuic',
          'tag': node['name'],
          'server': node['server'],
          'server_port': node['port'],
          'uuid': node['uuid'],
          'password': node['password'],
        };
      default:
        debugPrint('Unsupported node type for sing-box: $type');
        return null;
    }
  }

  /// 适配配置为 mihomo (Clash Meta) 格式
  static Map<String, dynamic> _adaptForMihomo(Map<String, dynamic> config) {
    final nodes = config['nodes'] as List<Map<String, dynamic>>? ?? [];
    
    final proxies = <Map<String, dynamic>>[];
    for (var node in nodes) {
      final proxy = _nodeToMihomoProxy(node);
      if (proxy != null) {
        proxies.add(proxy);
      }
    }

    final proxyNames = nodes.map((n) => n['name'] as String).toList();

    return {
      'port': config['http_port'] ?? 7890,
      'socks-port': config['socks_port'] ?? 7891,
      'allow-lan': false,
      'mode': 'rule',
      'log-level': config['log_level'] ?? 'info',
      'dns': {
        'enable': true,
        'listen': '0.0.0.0:53',
        'nameserver': ['223.5.5.5', '114.114.114.114'],
        'fallback': ['tls://8.8.8.8', 'tls://1.1.1.1'],
      },
      'proxies': proxies,
      'proxy-groups': [
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
      ],
      'rules': [
        'DST-PORT,53,DIRECT',
        'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
        'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
        'GEOIP,CN,DIRECT',
        'MATCH,PROXY',
      ],
    };
  }

  /// 将节点转换为 mihomo 代理配置
  static Map<String, dynamic>? _nodeToMihomoProxy(Map<String, dynamic> node) {
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
      case 'hysteria':
      case 'hysteria2':
        return {
          'name': node['name'],
          'type': 'hysteria2',
          'server': node['server'],
          'port': node['port'],
          'password': node['password'],
        };
      case 'tuic':
        return {
          'name': node['name'],
          'type': 'tuic',
          'server': node['server'],
          'port': node['port'],
          'uuid': node['uuid'],
          'password': node['password'],
        };
      default:
        debugPrint('Unsupported node type for mihomo: $type');
        return null;
    }
  }

  /// 适配配置为 v2ray (Xray) 格式
  static Map<String, dynamic> _adaptForV2Ray(Map<String, dynamic> config) {
    final nodes = config['nodes'] as List<Map<String, dynamic>>? ?? [];
    
    final outbounds = <Map<String, dynamic>>[
      {'protocol': 'freedom', 'tag': 'direct'},
      {'protocol': 'blackhole', 'tag': 'block'},
    ];

    // 转换节点为 v2ray 出站配置
    for (var node in nodes) {
      final outbound = _nodeToV2RayOutbound(node);
      if (outbound != null) {
        outbounds.add(outbound);
      }
    }

    return {
      'log': {
        'access': '',
        'error': '',
        'loglevel': config['log_level'] ?? 'info',
      },
      'inbounds': [
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
      ],
      'outbounds': outbounds,
      'routing': {
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
      },
      'dns': {
        'hosts': {},
        'servers': ['223.5.5.5', '8.8.8.8'],
      },
    };
  }

  /// 将节点转换为 v2ray 出站配置
  static Map<String, dynamic>? _nodeToV2RayOutbound(Map<String, dynamic> node) {
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
      case 'shadowsocks':
        return {
          'protocol': 'shadowsocks',
          'tag': node['name'],
          'settings': {
            'servers': [
              {
                'address': node['server'],
                'port': node['port'],
                'method': node['method'],
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
    } else if (network == 'tcp' && security == 'tls') {
      settings['realitySettings'] = node['realitySettings'];
    }

    return settings;
  }

  /// 简单的 JSON 转 YAML（基础实现）
  static String _convertToYaml(Map<String, dynamic> data, {int indent = 0}) {
    final buffer = StringBuffer();
    final prefix = '  ' * indent;
    
    data.forEach((key, value) {
      if (value is Map) {
        buffer.writeln('$prefix$key:');
        buffer.write(_convertToYaml(value, indent: indent + 1));
      } else if (value is List) {
        buffer.writeln('$prefix$key:');
        for (var item in value) {
          if (item is Map) {
            buffer.writeln('$prefix  -');
            buffer.write(_convertToYaml(item, indent: indent + 2));
          } else {
            buffer.writeln('$prefix  - $item');
          }
        }
      } else {
        buffer.writeln('$prefix$key: $value');
      }
    });
    
    return buffer.toString();
  }
}
