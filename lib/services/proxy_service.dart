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
  final List<String> _logs = [];
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  int? _latencyMs;

  ProxyState get state => _state;
  ProxyConfig get config => _config;
  NodeConfig? get activeNode => _activeNode;
  bool get isRunning => _state == ProxyState.running;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  List<String> get logs => List.unmodifiable(_logs);
  Stream<String> get logStream => _logController.stream;
  int? get latencyMs => _latencyMs;

  ProxyService(this._kernelManager);

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
    _latencyMs = null;
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
      } else {
        _addLog('[ProxyService] Process exited immediately with code $exitCode');
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
          [],
        );
      case KernelType.mihomo:
        configJson = ConfigAdapter.toMihomoConfig(
          _config,
          node,
          [],
        );
      case KernelType.v2ray:
        configJson = ConfigAdapter.toV2rayConfig(
          _config,
          node,
          [],
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
    } catch (_) {
      // Not a JSON traffic line, ignore
    }
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
    _logController.close();
    _process?.kill();
    super.dispose();
  }
}
