import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/config.dart';

class KernelExecutor extends ChangeNotifier {
  Process? _process;
  KernelType? _activeKernel;
  bool _isRunning = false;
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> _stderrController =
      StreamController<String>.broadcast();
  int? _pid;

  KernelType? get activeKernel => _activeKernel;
  bool get isRunning => _isRunning;
  int? get pid => _pid;
  Stream<String> get stdout => _stdoutController.stream;
  Stream<String> get stderr => _stderrController.stream;

  Future<bool> startKernel({
    required KernelType type,
    required String binaryPath,
    required String configPath,
    List<String> extraArgs = const [],
  }) async {
    if (_isRunning) {
      await stopKernel();
    }

    try {
      final args = _buildArgs(type, configPath, extraArgs);

      _process = await Process.start(binaryPath, args);

      _pid = _process!.pid;
      _activeKernel = type;
      _isRunning = true;
      notifyListeners();

      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _stdoutController.add(line);
          });

      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _stderrController.add(line);
          });

      _process!.exitCode.then((code) {
        debugPrint('[KernelExecutor] Process exited with code $code');
        _isRunning = false;
        _pid = null;
        _activeKernel = null;
        _process = null;
        notifyListeners();
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isRunning) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[KernelExecutor] Start failed: $e');
      _isRunning = false;
      _activeKernel = null;
      _process = null;
      _pid = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopKernel() async {
    if (_process == null || !_isRunning) return;

    try {
      final success = _process!.kill();
      if (!success) {
        _process!.kill(ProcessSignal.sigkill);
      }

      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      debugPrint('[KernelExecutor] Stopped with exit code $exitCode');
    } catch (e) {
      debugPrint('[KernelExecutor] Stop error: $e');
      try {
        _process?.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }

    _isRunning = false;
    _activeKernel = null;
    _process = null;
    _pid = null;
    notifyListeners();
  }

  Future<void> restartKernel({
    required KernelType type,
    required String binaryPath,
    required String configPath,
  }) async {
    await stopKernel();
    await Future.delayed(const Duration(milliseconds: 300));
    await startKernel(
      type: type,
      binaryPath: binaryPath,
      configPath: configPath,
    );
  }

  Future<int> getLatencyMs({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      stopwatch.stop();
      return -1;
    }
  }

  List<String> _buildArgs(
    KernelType type,
    String configPath,
    List<String> extraArgs,
  ) {
    switch (type) {
      case KernelType.singbox:
        return ['run', '-c', configPath, ...extraArgs];
      case KernelType.mihomo:
        return ['-f', configPath, ...extraArgs];
      case KernelType.v2ray:
        return ['run', '-c', configPath, ...extraArgs];
    }
  }

  @override
  void dispose() {
    _stdoutController.close();
    _stderrController.close();
    _process?.kill();
    super.dispose();
  }
}
