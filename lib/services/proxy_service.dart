import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/config.dart';
import '../utils/config_adapter.dart';
import 'kernel_manager.dart';

enum ProxyState {
  stopped,
  starting,
  running,
  stopping,
}

class ProxyService extends ChangeNotifier {
  final KernelManager _kernelManager;
  ProxyState _state = ProxyState.stopped;
  ProxyConfig _config = ProxyConfig();
  NodeConfig? _activeNode;
  Process? _process;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  int _lastUploadBytes = 0;
  int _lastDownloadBytes = 0;
  final List<String> _logs = [];
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  int? _latencyMs;
  List<RoutingRule> _routingRules = [];
  Timer? _speedTimer;
  final List<SpeedRecord> _speedHistory = [];

  ProxyState get state => _state;
  ProxyConfig get config => _config;
  NodeConfig? get activeNode => _activeNode;
  bool get isRunning => _state == ProxyState.running;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  List<String> get logs => List.unmodifiable(_logs);
  Stream<String> get logStream => _logController.stream;
  int? get latencyMs => _latencyMs;
  List<RoutingRule> get routingRules => _routingRules;
  List<SpeedRecord> get speedHistory => List.unmodifiable(_speedHistory);

  ProxyService(this._kernelManager) {
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateSpeed();
    });
  }

  void _updateSpeed() {
    _uploadSpeed = _uploadBytes - _lastUploadBytes;
    _downloadSpeed = _downloadBytes - _lastDownloadBytes;
    _lastUploadBytes = _uploadBytes;
    _lastDownloadBytes = _downloadBytes;

    if (isRunning) {
      _speedHistory.add(SpeedRecord(
        time: DateTime.now(),
        upload: _uploadSpeed,
        download: _downloadSpeed,
      ));
      if (_speedHistory.length > 60) {
        _speedHistory.removeRange(0, _speedHistory.length - 60);
      }
    }

    notifyListeners();
  }

  void updateConfig(ProxyConfig config) {
    _config = config;
    notifyListeners();
  }

  void updateRoutingRules(List<RoutingRule> rules) {
    _routingRules = rules;
    notifyListeners();
  }

  Future<void> start(NodeConfig node) async {
    if (_state == ProxyState.running || _state == ProxyState.starting) return;

    _activeNode = node;
    _state = ProxyState.starting;
    _uploadBytes = 0;
    _downloadBytes = 0;
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _lastUploadBytes = 0;
    _lastDownloadBytes = 0;
    _latencyMs = null;
    _speedHistory.clear();
    notifyListeners();

    _addLog('[ProxyService] Starting proxy with ${node.name}...');

    try {
      final binaryPath = await _getKernelBinaryPath();
      final configPath = await _writeKernelConfig(node);
      final args = _buildKernelArgs(configPath);

      _process = await Process.start(binaryPath, args);

      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog(line);
        _parseTrafficLine(line);
      });

      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog('[ERROR] $line');
      });

      _process!.exitCode.then((code) {
        _addLog('[ProxyService] Process exited with code $code');
        if (_state == ProxyState.starting || _state == ProxyState.running) {
          _state = ProxyState.stopped;
          _activeNode = null;
          notifyListeners();
        }
      });

      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );

      if (exitCode == -1) {
        _state = ProxyState.running;
        _addLog('[ProxyService] Proxy started successfully');
        testLatency(node);
      } else {
        _addLog(
            '[ProxyService] Process exited immediately with code $exitCode');
        _state = ProxyState.stopped;
        _activeNode = null;
      }
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
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _addLog('[ProxyService] Proxy stopped');
    notifyListeners();
  }

  Future<void> restart(NodeConfig node) async {
    await stop();
    await start(node);
  }

  Future<int> testLatency(NodeConfig node) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        node.address,
        node.port,
        timeout: const Duration(seconds: 5),
      );
      stopwatch.stop();
      socket.destroy();
      _latencyMs = stopwatch.elapsedMilliseconds;
    } catch (_) {
      stopwatch.stop();
      _latencyMs = -1;
    }
    notifyListeners();
    return _latencyMs!;
  }

  Future<void> testAllLatency(List<NodeConfig> nodes) async {
    final futures = nodes.map((node) async {
      final stopwatch = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          node.address,
          node.port,
          timeout: const Duration(seconds: 5),
        );
        stopwatch.stop();
        socket.destroy();
        node.latencyMs = stopwatch.elapsedMilliseconds;
      } catch (_) {
        stopwatch.stop();
        node.latencyMs = -1;
      }
    });
    await Future.wait(futures);
    notifyListeners();
  }

  Future<double> testDownloadSpeed(NodeConfig node) async {
    try {
      final stopwatch = Stopwatch()..start();
      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('https://cachefly.cachefly.net/1mb.test'));
      final response = await request.close();

      int totalBytes = 0;
      await for (final chunk in response) {
        totalBytes += chunk.length;
      }
      stopwatch.stop();

      client.close();

      if (stopwatch.elapsedMilliseconds > 0) {
        final speed = (totalBytes * 1000) / stopwatch.elapsedMilliseconds;
        node.downloadSpeed = speed;
        notifyListeners();
        return speed;
      }
    } catch (e) {
      node.downloadSpeed = -1;
      notifyListeners();
    }
    return -1;
  }

  NodeConfig? findBestNode(List<NodeConfig> nodes) {
    final tested = nodes.where((n) => n.latencyMs != null && n.latencyMs! > 0);
    if (tested.isEmpty) return null;
    return tested.reduce((a, b) =>
        (a.latencyMs ?? 9999) < (b.latencyMs ?? 9999) ? a : b);
  }

  Future<String> _getKernelBinaryPath() async {
    return _kernelManager.getBinaryPath(_config.kernelType);
  }

  List<String> _buildKernelArgs(String configPath) {
    switch (_config.kernelType) {
      case KernelType.singbox:
        return ['run', '-c', configPath];
      case KernelType.mihomo:
        return ['-f', configPath];
      case KernelType.v2ray:
        return ['run', '-c', configPath];
    }
  }

  Future<String> _writeKernelConfig(NodeConfig node) async {
    final dir = Directory.systemTemp.createTempSync('singbox_config_');
    final file = File('${dir.path}/config.json');

    Map<String, dynamic> configJson;
    switch (_config.kernelType) {
      case KernelType.singbox:
        configJson = ConfigAdapter.toSingboxConfig(
          _config,
          node,
          _routingRules,
        );
      case KernelType.mihomo:
        configJson = ConfigAdapter.toMihomoConfig(
          _config,
          node,
          _routingRules,
        );
      case KernelType.v2ray:
        configJson = ConfigAdapter.toV2rayConfig(
          _config,
          node,
          _routingRules,
        );
    }

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(configJson),
    );
    return file.path;
  }

  void _parseTrafficLine(String line) {
    try {
      if (line.trim().startsWith('{')) {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json.containsKey('upload') && json.containsKey('download')) {
          final up = json['upload'] as int? ?? 0;
          final down = json['download'] as int? ?? 0;
          _uploadBytes = up;
          _downloadBytes = down;
          notifyListeners();
        }
      }
    } catch (_) {}
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

  @override
  void dispose() {
    _speedTimer?.cancel();
    _logController.close();
    _process?.kill();
    super.dispose();
  }
}

class SpeedRecord {
  final DateTime time;
  final int upload;
  final int download;

  const SpeedRecord({
    required this.time,
    required this.upload,
    required this.download,
  });
}
