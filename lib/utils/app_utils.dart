import 'dart:convert';
import 'dart:io';

/// Utility functions for network, file operations, and data processing
class AppUtils {
  /// Test network connectivity and latency to a host
  static Future<Map<String, dynamic>> testConnectivity({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(
        host,
        port,
        timeout: timeout,
      ).timeout(timeout);
      
      stopwatch.stop();
      await socket.close();
      
      return {
        'success': true,
        'latency': stopwatch.elapsedMilliseconds,
        'host': host,
        'port': port,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'host': host,
        'port': port,
      };
    }
  }

  /// Parse a subscription URL and extract nodes
  static Future<List<Map<String, dynamic>>> parseSubscription(String url) async {
    // In real app, this would fetch and decode the subscription
    // For now, return empty list
    return [];
  }

  /// Parse a single proxy link (vmess://, vless://, trojan://, etc.)
  static Map<String, dynamic>? parseProxyLink(String link) {
    try {
      if (link.startsWith('vmess://')) {
        return _parseVmess(link);
      } else if (link.startsWith('vless://')) {
        return _parseVless(link);
      } else if (link.startsWith('trojan://')) {
        return _parseTrojan(link);
      } else if (link.startsWith('ss://')) {
        return _parseShadowsocks(link);
      } else if (link.startsWith('hysteria://') || link.startsWith('hysteria2://')) {
        return _parseHysteria(link);
      } else if (link.startsWith('tuic://')) {
        return _parseTuic(link);
      }
    } catch (e) {
      print('Failed to parse link: $e');
    }
    return null;
  }

  static Map<String, dynamic>? _parseVmess(String link) {
    try {
      final base64Data = link.substring(8);
      final decoded = utf8.decode(base64Decode(base64Data));
      final jsonMap = jsonDecode(decoded);
      
      return {
        'type': 'vmess',
        'tag': jsonMap['ps'] ?? 'VMess Node',
        'server': jsonMap['add'],
        'serverPort': int.tryParse(jsonMap['port'].toString()),
        'uuid': jsonMap['id'],
        'security': jsonMap['scy'] ?? 'auto',
        'tls': jsonMap['tls'] == 'tls' ? {'enabled': true} : null,
        'transport': _parseVmessTransport(jsonMap),
      };
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseTransport(dynamic jsonMap) {
    final net = jsonMap['net'] ?? 'tcp';
    final transport = <String, dynamic>{'type': net};
    
    if (net == 'ws') {
      transport['path'] = jsonMap['path'] ?? '/';
      if (jsonMap['host'] != null) {
        transport['headers'] = {'Host': jsonMap['host']};
      }
    } else if (net == 'grpc') {
      transport['serviceName'] = jsonMap['path'] ?? '';
    } else if (net == 'http' || net == 'h2') {
      transport['path'] = jsonMap['path'] ?? '/';
    }
    
    return transport;
  }

  static Map<String, dynamic>? _parseVmessTransport(dynamic jsonMap) {
    return _parseTransport(jsonMap);
  }

  static Map<String, dynamic>? _parseVless(String link) {
    try {
      final uri = Uri.parse(link);
      final query = uri.queryParameters;
      
      return {
        'type': 'vless',
        'tag': query['remarks'] ?? 'VLESS Node',
        'server': uri.host,
        'serverPort': uri.port,
        'uuid': uri.userInfo,
        'flow': query['flow'],
        'security': query['security'] ?? 'none',
        'tls': query['security'] == 'tls' || query['security'] == 'reality'
            ? {
                'enabled': true,
                'serverName': query['sni'] ?? query['host'],
                'insecure': query['allowInsecure'] == '1',
              }
            : null,
        'reality': query['security'] == 'reality'
            ? {
                'enabled': true,
                'publicKey': query['pbk'],
                'shortId': query['sid'],
              }
            : null,
        'transport': _parseTransportFromQuery(query),
      };
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseTrojan(String link) {
    try {
      final uri = Uri.parse(link);
      final query = uri.queryParameters;
      
      return {
        'type': 'trojan',
        'tag': query['remarks'] ?? 'Trojan Node',
        'server': uri.host,
        'serverPort': uri.port,
        'password': uri.userInfo,
        'tls': {
          'enabled': true,
          'serverName': query['sni'] ?? query['host'],
          'insecure': query['allowInsecure'] == '1',
        },
        'transport': _parseTransportFromQuery(query),
      };
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseShadowsocks(String link) {
    try {
      final uri = Uri.parse(link);
      String? userInfo = uri.userInfo;
      
      // Try to decode base64 encoded user info
      if (!userInfo.contains(':')) {
        try {
          userInfo = utf8.decode(base64Decode(userInfo));
        } catch (_) {}
      }
      
      final parts = userInfo.split(':');
      final method = parts[0];
      final password = parts.length > 1 ? parts.sublist(1).join(':') : '';
      
      return {
        'type': 'shadowsocks',
        'tag': uri.fragment.isNotEmpty ? uri.fragment : 'Shadowsocks Node',
        'server': uri.host,
        'serverPort': uri.port,
        'password': password,
      };
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseHysteria(String link) {
    try {
      final uri = Uri.parse(link);
      final query = uri.queryParameters;
      
      return {
        'type': link.contains('hysteria2') ? 'hysteria2' : 'hysteria',
        'tag': query['remarks'] ?? 'Hysteria Node',
        'server': uri.host,
        'serverPort': uri.port,
        'password': uri.userInfo,
        'upMbps': query['upmbps'],
        'downMbps': query['downmbps'],
        'obfsPassword': query['obfsParam'],
        'tls': {
          'enabled': true,
          'serverName': query['sni'] ?? query['host'],
          'insecure': query['insecure'] == '1',
        },
      };
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseTuic(String link) {
    try {
      final uri = Uri.parse(link);
      final query = uri.queryParameters;
      
      return {
        'type': 'tuic',
        'tag': query['remarks'] ?? 'TUIC Node',
        'server': uri.host,
        'serverPort': uri.port,
        'uuid': uri.userInfo.split(':').first,
        'password': uri.userInfo.split(':').skip(1).join(':'),
        'congestionControl': query['congestion_control'] ?? 'bbr',
        'tls': {
          'enabled': true,
          'serverName': query['sni'] ?? query['host'],
        },
      };
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseTransportFromQuery(Map<String, String> query) {
    final type = query['type'] ?? 'tcp';
    if (type == 'tcp' || type == 'none') return null;
    
    final transport = <String, dynamic>{'type': type};
    
    if (type == 'ws') {
      transport['path'] = query['path'] ?? '/';
      if (query['host'] != null) {
        transport['headers'] = {'Host': query['host']};
      }
    } else if (type == 'grpc') {
      transport['serviceName'] = query['serviceName'] ?? '';
    } else if (type == 'http' || type == 'h2') {
      transport['path'] = query['path'] ?? '/';
    }
    
    return transport.isEmpty ? null : transport;
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Validate IP address or CIDR
  static bool isValidIpCidr(String ipCidr) {
    final regex = RegExp(
      r'^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$|^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}(/\d{1,3})?$',
    );
    return regex.hasMatch(ipCidr);
  }

  /// Validate domain name
  static bool isValidDomain(String domain) {
    final regex = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(domain);
  }
}
