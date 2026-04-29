import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ClashApiService extends ChangeNotifier {
  final Dio _dio = Dio();
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  String _apiUrl = 'http://127.0.0.1:9090';
  String _secret = '';

  int _liveUpload = 0;
  int _liveDownload = 0;
  List<ClashConnection> _connections = [];
  List<ClashLogEntry> _realtimeLogs = [];
  String _currentProxyMode = 'rule';

  int get liveUpload => _liveUpload;
  int get liveDownload => _liveDownload;
  List<ClashConnection> get connections => List.unmodifiable(_connections);
  List<ClashLogEntry> get realtimeLogs => List.unmodifiable(_realtimeLogs);
  String get currentProxyMode => _currentProxyMode;
  bool get isConnected => _wsChannel != null;

  void configure({required String apiUrl, String? secret}) {
    _apiUrl = apiUrl.replaceAll(RegExp(r'/$'), '');
    _secret = secret ?? '';
    _dio.options.baseUrl = _apiUrl;
    if (_secret.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_secret';
    }
  }

  Future<void> connect() async {
    await disconnect();

    try {
      final wsUrl = _apiUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/traffic?token=$_secret');
      _wsChannel = WebSocketChannel.connect(uri);

      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json.containsKey('up') && json.containsKey('down')) {
              _liveUpload = (json['up'] as num).toInt();
              _liveDownload = (json['down'] as num).toInt();
              notifyListeners();
            }
          } catch (_) {}
        },
        onError: (e) {
          debugPrint('[ClashApi] WebSocket error: $e');
          _reconnect();
        },
        onDone: () {
          debugPrint('[ClashApi] WebSocket closed');
          _reconnect();
        },
      );

      await _connectLogsStream();
      notifyListeners();
    } catch (e) {
      debugPrint('[ClashApi] Connect failed: $e');
    }
  }

  Future<void> _connectLogsStream() async {
    try {
      final wsUrl = _apiUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/logs?token=$_secret&level=info');
      final logChannel = WebSocketChannel.connect(uri);

      logChannel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final entry = ClashLogEntry(
              type: json['type'] as String? ?? 'info',
              payload: json['payload'] as String? ?? '',
            );
            _realtimeLogs = [..._realtimeLogs, entry];
            if (_realtimeLogs.length > 500) {
              _realtimeLogs = _realtimeLogs.sublist(_realtimeLogs.length - 500);
            }
            notifyListeners();
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  Timer? _reconnectTimer;
  void _reconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () => connect());
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _liveUpload = 0;
    _liveDownload = 0;
    notifyListeners();
  }

  Future<List<ClashProxy>> getProxies() async {
    try {
      final resp = await _dio.get('/proxies');
      final data = resp.data as Map<String, dynamic>;
      final proxies = data['proxies'] as Map<String, dynamic>;
      return proxies.entries
          .map((e) => ClashProxy.fromJson(e.key, e.value as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> switchProxy(String group, String name) async {
    try {
      await _dio.put('/proxies/$group', data: {'name': name});
    } catch (_) {}
  }

  Future<void> setProxyMode(String mode) async {
    try {
      await _dio.patch('/configs', data: {'mode': mode});
      _currentProxyMode = mode;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchConnections() async {
    try {
      final resp = await _dio.get('/connections');
      final data = resp.data as Map<String, dynamic>;
      final conns = data['connections'] as List? ?? [];
      _connections = conns
          .map((c) => ClashConnection.fromJson(c as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> closeAllConnections() async {
    try {
      await _dio.delete('/connections');
      _connections.clear();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    super.dispose();
  }
}

class ClashProxy {
  final String name;
  final String type;
  final String? now;
  final int? delay;
  final List<String> all;

  const ClashProxy({
    required this.name,
    required this.type,
    this.now,
    this.delay,
    this.all = const [],
  });

  factory ClashProxy.fromJson(String name, Map<String, dynamic> json) {
    return ClashProxy(
      name: name,
      type: json['type'] as String? ?? '',
      now: json['now'] as String?,
      delay: json['history'] != null && (json['history'] as List).isNotEmpty
          ? (json['history'][0]['delay'] as num?)?.toInt()
          : null,
      all: (json['all'] as List?)?.cast<String>() ?? [],
    );
  }

  bool get isGroup => type == 'Selector' || type == 'URLTest' || type == 'Fallback';
}

class ClashConnection {
  final String id;
  final String host;
  final String destinationIP;
  final String destinationPort;
  final String chain;
  final int upload;
  final int download;
  final DateTime start;

  const ClashConnection({
    required this.id,
    required this.host,
    this.destinationIP = '',
    this.destinationPort = '',
    this.chain = '',
    this.upload = 0,
    this.download = 0,
    required this.start,
  });

  factory ClashConnection.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};
    return ClashConnection(
      id: json['id'] as String? ?? '',
      host: meta['host'] as String? ?? meta['destinationIP'] as String? ?? '',
      destinationIP: meta['destinationIP'] as String? ?? '',
      destinationPort: meta['destinationPort'] as String? ?? '',
      chain: (json['chains'] as List?)?.join(' → ') ?? '',
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ClashLogEntry {
  final String type;
  final String payload;

  const ClashLogEntry({required this.type, required this.payload});
}
