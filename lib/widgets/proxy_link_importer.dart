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
      default:
        throw UnimplementedError('Protocol $protocol parsing not implemented');
    }
  }

  NodeConfig _parseVmess(String uri) {
    throw UnimplementedError('Use SubscriptionService for VMess parsing');
  }

  NodeConfig _parseUriBased(String uri, ProxyProtocol protocol) {
    final parsed = Uri.parse(uri);
    final params = parsed.queryParameters;
    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: params['name'] ?? parsed.fragment ?? protocol.label,
      protocol: protocol,
      address: parsed.host.isEmpty ? '0.0.0.0' : parsed.host,
      port: parsed.port == 0 ? 443 : parsed.port,
      extra: {'rawUri': uri},
    );
  }

  NodeConfig _parseShadowsocks(String uri) {
    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Shadowsocks',
      protocol: ProxyProtocol.shadowsocks,
      address: '0.0.0.0',
      port: 443,
      extra: {'rawUri': uri},
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
              hintText: '粘贴代理链接 (vmess://, vless://, trojan://, ss://, ...)',
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
