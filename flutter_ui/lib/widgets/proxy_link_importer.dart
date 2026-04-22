import 'dart:convert';
import 'package:flutter/material.dart';

/// A widget that displays a list of proxy links and allows importing them
class ProxyLinkImporter extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onLinksParsed;

  const ProxyLinkImporter({super.key, required this.onLinksParsed});

  @override
  State<ProxyLinkImporter> createState() => _ProxyLinkImporterState();
}

class _ProxyLinkImporterState extends State<ProxyLinkImporter> {
  final TextEditingController _controller = TextEditingController();
  bool _isParsing = false;
  List<Map<String, dynamic>> _parsedNodes = [];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parseLinks() async {
    setState(() {
      _isParsing = true;
      _error = null;
      _parsedNodes = [];
    });

    try {
      final lines = _controller.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final parsed = <Map<String, dynamic>>[];
      for (final line in lines) {
        final result = _parseSingleLink(line);
        if (result != null) {
          parsed.add(result);
        }
      }

      setState(() {
        _parsedNodes = parsed;
        _isParsing = false;
      });

      if (parsed.isEmpty && lines.isNotEmpty) {
        setState(() {
          _error = 'No valid proxy links found. Supported formats: vmess://, vless://, trojan://, ss://, hysteria://, hysteria2://, tuic://';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error parsing links: $e';
        _isParsing = false;
      });
    }
  }

  Map<String, dynamic>? _parseSingleLink(String link) {
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

  Map<String, dynamic>? _parseVmess(String link) {
    try {
      final base64Data = link.substring(8);
      // Handle potential padding issues
      final normalized = base64Data.padRight(base64Data.length + (4 - base64Data.length % 4) % 4, '=');
      final decoded = utf8.decode(base64Decode(normalized));
      final jsonMap = jsonDecode(decoded);
      
      return {
        'type': 'vmess',
        'tag': jsonMap['ps'] ?? 'VMess Node',
        'server': jsonMap['add'],
        'serverPort': int.tryParse(jsonMap['port'].toString()),
        'uuid': jsonMap['id'],
        'security': jsonMap['scy'] ?? 'auto',
        'tls': jsonMap['tls'] == 'tls' ? {'enabled': true, 'serverName': jsonMap['host']} : null,
        'transport': _parseTransport(jsonMap),
      };
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _parseTransport(dynamic jsonMap) {
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
    
    return transport.isEmpty ? null : transport;
  }

  Map<String, dynamic>? _parseVless(String link) {
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

  Map<String, dynamic>? _parseTrojan(String link) {
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

  Map<String, dynamic>? _parseShadowsocks(String link) {
    try {
      final uri = Uri.parse(link);
      String? userInfo = uri.userInfo;
      
      // Try to decode base64 encoded user info
      if (!userInfo.contains(':')) {
        try {
          final normalized = userInfo.padRight(userInfo.length + (4 - userInfo.length % 4) % 4, '=');
          userInfo = utf8.decode(base64Decode(normalized));
        } catch (_) {}
      }
      
      final parts = userInfo.split(':');
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

  Map<String, dynamic>? _parseHysteria(String link) {
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

  Map<String, dynamic>? _parseTuic(String link) {
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

  Map<String, dynamic>? _parseTransportFromQuery(Map<String, String> query) {
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

  void _importNodes() {
    if (_parsedNodes.isNotEmpty) {
      widget.onLinksParsed(_parsedNodes);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Proxy Links',
            hintText: 'Paste one or more proxy links (vmess://, vless://, etc.)',
            border: OutlineInputBorder(),
          ),
          maxLines: 10,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isParsing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isParsing ? null : _parseLinks,
              icon: _isParsing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isParsing ? 'Parsing...' : 'Parse Links'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ],
        if (_parsedNodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('Found ${_parsedNodes.length} valid proxy link(s)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _parsedNodes.length,
              itemBuilder: (ctx, i) {
                final node = _parsedNodes[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: _getProtocolIcon(node['type']),
                    title: Text(node['tag']),
                    subtitle: Text('${node['server']}:${node['serverPort']}'),
                    trailing: Chip(
                      label: Text(node['type'].toUpperCase()),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _importNodes,
            icon: const Icon(Icons.add),
            label: const Text('Import All Nodes'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        ],
      ],
    );
  }

  Widget _getProtocolIcon(String type) {
    switch (type) {
      case 'vmess':
        return const Icon(Icons.flash_on, color: Colors.orange);
      case 'vless':
        return const Icon(Icons.bolt, color: Colors.amber);
      case 'trojan':
        return const Icon(Icons.shield, color: Colors.purple);
      case 'shadowsocks':
        return const Icon(Icons.lock, color: Colors.blue);
      case 'hysteria':
      case 'hysteria2':
        return const Icon(Icons.rocket, color: Colors.red);
      case 'tuic':
        return const Icon(Icons.speed, color: Colors.teal);
      default:
        return const Icon(Icons.public);
    }
  }
}
