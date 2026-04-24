import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/config.dart';

enum ProxyState {
  stopped,
  starting,
  running,
  stopping,
}

class ProxyService extends ChangeNotifier {
  ProxyState _state = ProxyState.stopped;
  ProxyConfig _config = ProxyConfig();
  NodeConfig? _activeNode;
  Process? _process;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  final List<String> _logs = [];
  final StreamController<String> _logController = StreamController<String>.broadcast();

  ProxyState get state => _state;
  ProxyConfig get config => _config;
  NodeConfig? get activeNode => _activeNode;
  bool get isRunning => _state == ProxyState.running;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  List<String> get logs => List.unmodifiable(_logs);
  Stream<String> get logStream => _logController.stream;

  void updateConfig(ProxyConfig config) {
    _config = config;
    notifyListeners();
  }

  Future<void> start(NodeConfig node) async {
    if (_state == ProxyState.running || _state == ProxyState.starting) return;

    _activeNode = node;
    _state = ProxyState.starting;
    _uploadBytes = 0;
    _downloadBytes = 0;
    notifyListeners();

    _addLog('[ProxyService] Starting proxy with ${node.name}...');

    try {
      final binaryPath = await _getKernelBinaryPath();
      final configPath = await _writeKernelConfig(node);

      _process = await Process.start(
        binaryPath,
        ['run', '-c', configPath],
      );

      _process!.stdout.transform(const SystemEncoding().decoder).listen((data) {
        _addLog(data.trim());
      });

      _process!.stderr.transform(const SystemEncoding().decoder).listen((data) {
        _addLog('[ERROR] ${data.trim()}');
      });

      _process!.exitCode.then((code) {
        _addLog('[ProxyService] Process exited with code $code');
        if (_state != ProxyState.stopping) {
          _state = ProxyState.stopped;
          _activeNode = null;
          notifyListeners();
        }
      });

      await Future.delayed(const Duration(seconds: 1));

      _state = ProxyState.running;
      _addLog('[ProxyService] Proxy started successfully');
    } catch (e) {
      _addLog('[ProxyService] Failed to start: $e');
      _state = ProxyState.stopped;
      _activeNode = null;
    }

    notifyListeners();
  }

  Future<void> stop() async {
    if (_state != ProxyState.running && _state != ProxyState.starting) return;

    _state = ProxyState.stopping;
    _addLog('[ProxyService] Stopping proxy...');
    notifyListeners();

    try {
      _process?.kill();
      await _process?.exitCode.timeout(const Duration(seconds: 5));
    } catch (e) {
      _addLog('[ProxyService] Force killing process...');
      _process?.kill(ProcessSignal.sigkill);
    }

    _process = null;
    _state = ProxyState.stopped;
    _activeNode = null;
    _addLog('[ProxyService] Proxy stopped');
    notifyListeners();
  }

  Future<void> restart(NodeConfig node) async {
    await stop();
    await start(node);
  }

  Future<void> testLatency(NodeConfig node) async {
    try {
      final socket = await Socket.connect(
        node.address,
        node.port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
    } catch (_) {
      // Latency test failed
    }
  }

  Future<String> _getKernelBinaryPath() async {
    return 'sing-box';
  }

  Future<String> _writeKernelConfig(NodeConfig node) async {
    final dir = Directory.systemTemp.createTempSync('singbox_config_');
    final file = File('${dir.path}/config.json');
    await file.writeAsString('{"log":{"level":"info"},"inbounds":[],"outbounds":[]}');
    return file.path;
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] $message';
    _logs.add(logLine);
    if (_logs.length > 1000) {
      _logs.removeRange(0, _logs.length - 1000);
    }
    _logController.add(logLine);
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void addTraffic(int upload, int download) {
    _uploadBytes += upload;
    _downloadBytes += download;
    notifyListeners();
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _logController.close();
    _process?.kill();
    super.dispose();
  }
}
