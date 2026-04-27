import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/config.dart';
import '../utils/app_utils.dart';

class ProxyLinkImporter extends StatefulWidget {
  final void Function(NodeConfig) onImport;

  const ProxyLinkImporter({super.key, required this.onImport});

  @override
  State<ProxyLinkImporter> createState() => _ProxyLinkImporterState();
}

class _ProxyLinkImporterState extends State<ProxyLinkImporter> {
  final _controller = TextEditingController();
  ProxyProtocol? _detectedProtocol;
  String? _parseError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detectProtocol(String text) {
    final trimmed = text.trim();
    setState(() {
      _parseError = null;
      _detectedProtocol = null;

      if (trimmed.startsWith('vmess://')) {
        _detectedProtocol = ProxyProtocol.vmess;
      } else if (trimmed.startsWith('vless://')) {
        _detectedProtocol = ProxyProtocol.vless;
      } else if (trimmed.startsWith('trojan://')) {
        _detectedProtocol = ProxyProtocol.trojan;
      } else if (trimmed.startsWith('ss://')) {
        _detectedProtocol = ProxyProtocol.shadowsocks;
      } else if (trimmed.startsWith('hysteria2://') || trimmed.startsWith('hy2://')) {
        _detectedProtocol = ProxyProtocol.hysteria2;
      } else if (trimmed.startsWith('hysteria://')) {
        _detectedProtocol = ProxyProtocol.hysteria;
      } else if (trimmed.startsWith('tuic://')) {
        _detectedProtocol = ProxyProtocol.tuic;
      } else if (trimmed.isEmpty) {
        _detectedProtocol = null;
      } else {
        _parseError = '无法识别的协议格式';
      }
    });
  }

  void _import() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_detectedProtocol == null) {
      setState(() => _parseError = '无法识别的协议格式');
      return;
    }

    try {
      final node = _parseLink(text, _detectedProtocol!);
      widget.onImport(node);
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _parseError = '解析失败: $e');
    }
  }

  NodeConfig _parseLink(String uri, ProxyProtocol protocol) {
    switch (protocol) {
      case ProxyProtocol.vmess:
        return _parseVmess(uri);
      case ProxyProtocol.vless:
      case ProxyProtocol.trojan:
      case ProxyProtocol.hysteria2:
        return _parseUriBased(uri, protocol);
      case ProxyProtocol.shadowsocks:
        return _parseShadowsocks(uri);
      case ProxyProtocol.hysteria:
        return _parseHysteria(uri);
      case ProxyProtocol.tuic:
        return _parseTuic(uri);
      case ProxyProtocol.naive:
      case ProxyProtocol.wireguard:
        throw UnimplementedError(
          '${protocol.label} protocol link parsing is not supported yet. '
          'Please add the node manually.',
        );
    }
  }

  NodeConfig _parseVmess(String uri) {
    try {
      final encoded = uri.replaceFirst('vmess://', '');
      final decoded = utf8.decode(base64Decode(encoded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return NodeConfig(
        id: json['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['ps'] as String? ?? 'VMess',
        protocol: ProxyProtocol.vmess,
        address: json['add'] as String? ?? '',
        port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
        extra: {
          'uuid': json['id'],
          'alterId': json['aid'] ?? 0,
          'security': json['scy'] ?? 'auto',
          'network': json['net'] ?? 'tcp',
          'wsPath': json['path'],
          'wsHost': json['host'],
        },
      );
    } catch (e) {
      throw FormatException('VMess 链接解析失败: $e');
    }
  }

  NodeConfig _parseUriBased(String uri, ProxyProtocol protocol) {
    final parsed = Uri.parse(uri);
    final params = parsed.queryParameters;
    final name = params['name'] ?? parsed.fragment;
    final effectiveName = name.isEmpty ? protocol.label : name;

    Map<String, dynamic> extra;
    switch (protocol) {
      case ProxyProtocol.vless:
        extra = {
          'uuid': parsed.userInfo,
          'flow': params['flow'],
          'security': params['security'] ?? 'none',
          'type': params['type'] ?? 'tcp',
          'sni': params['sni'],
        };
      case ProxyProtocol.trojan:
        extra = {
          'password': parsed.userInfo,
          'sni': params['sni'],
          'type': params['type'] ?? 'tcp',
        };
      case ProxyProtocol.hysteria2:
        extra = {
          'password': parsed.userInfo,
          'sni': params['sni'],
          'insecure': params['insecure'] == '1',
        };
      default:
        extra = {'rawUri': uri};
    }

    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      protocol: protocol,
      address: parsed.host.isEmpty ? '0.0.0.0' : parsed.host,
      port: parsed.port == 0 ? 443 : parsed.port,
      extra: extra,
    );
  }

  NodeConfig _parseShadowsocks(String uri) {
    try {
      final content = uri.replaceFirst('ss://', '');
      final hashIndex = content.indexOf('#');
      final name = hashIndex >= 0
          ? Uri.decodeComponent(content.substring(hashIndex + 1))
          : 'Shadowsocks';
      final body = hashIndex >= 0 ? content.substring(0, hashIndex) : content;

      final atIndex = body.indexOf('@');
      if (atIndex < 0) throw const FormatException('Invalid SS URI format');

      final methodAndPassword =
          utf8.decode(base64Decode(body.substring(0, atIndex)));
      final colonIndex = methodAndPassword.indexOf(':');
      final method = methodAndPassword.substring(0, colonIndex);
      final password = methodAndPassword.substring(colonIndex + 1);

      final serverPart = body.substring(atIndex + 1);
      final colonPos = serverPart.lastIndexOf(':');

      return NodeConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        protocol: ProxyProtocol.shadowsocks,
        address: serverPart.substring(0, colonPos),
        port: int.parse(serverPart.substring(colonPos + 1)),
        extra: {
          'method': method,
          'password': password,
        },
      );
    } catch (e) {
      throw FormatException('Shadowsocks 链接解析失败: $e');
    }
  }

  NodeConfig _parseHysteria(String uri) {
    final parsed = Uri.parse(uri);
    final params = parsed.queryParameters;
    final name = params['name'] ?? parsed.fragment;
    final effectiveName = name.isEmpty ? 'Hysteria' : name;
    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      protocol: ProxyProtocol.hysteria,
      address: parsed.host.isEmpty ? '0.0.0.0' : parsed.host,
      port: parsed.port == 0 ? 443 : parsed.port,
      extra: {
        'auth': params['auth'] ?? parsed.userInfo,
        'sni': params['sni'],
        'insecure': params['insecure'] == '1',
      },
    );
  }

  NodeConfig _parseTuic(String uri) {
    final parsed = Uri.parse(uri);
    final params = parsed.queryParameters;
    final name = params['name'] ?? parsed.fragment;
    final effectiveName = name.isEmpty ? 'TUIC' : name;
    final userInfo = parsed.userInfo.split(':');
    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      protocol: ProxyProtocol.tuic,
      address: parsed.host.isEmpty ? '0.0.0.0' : parsed.host,
      port: parsed.port == 0 ? 443 : parsed.port,
      extra: {
        'uuid': userInfo.isNotEmpty ? userInfo[0] : '',
        'password': userInfo.length > 1 ? userInfo[1] : '',
        'sni': params['sni'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '导入代理链接',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  '粘贴代理链接 (vmess://, vless://, trojan://, ss://, hy2://, ...)',
              border: const OutlineInputBorder(),
              suffixIcon: _detectedProtocol != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${AppUtils.protocolIcon(_detectedProtocol!)} ${_detectedProtocol!.label}',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : null,
              errorText: _parseError,
            ),
            onChanged: _detectProtocol,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _detectedProtocol != null ? _import : null,
                child: const Text('导入'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
