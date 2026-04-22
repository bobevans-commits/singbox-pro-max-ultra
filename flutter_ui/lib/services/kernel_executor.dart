import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/config.dart';

/// 内核执行器 - 负责启动和管理内核进程
class KernelExecutor {
  Process? _process;
  String? _kernelPath;
  KernelType _currentType = KernelType.singBox;
  final StreamController<String> _logController = StreamController<String>.broadcast();
  bool _isRunning = false;

  // Getters
  Stream<String> get logStream => _logController.stream;
  bool get isRunning => _isRunning;
  KernelType get currentType => _currentType;
  int? get pid => _process?.pid;

  /// 启动内核
  Future<bool> start({
    required String kernelPath,
    required KernelType type,
    required String configPath,
  }) async {
    if (_isRunning) {
      debugPrint('Kernel is already running');
      return false;
    }

    try {
      _kernelPath = kernelPath;
      _currentType = type;

      final file = File(kernelPath);
      if (!await file.exists()) {
        _logController.add('Error: Kernel file not found: $kernelPath');
        return false;
      }

      List<String> args;
      switch (type) {
        case KernelType.singBox:
          args = ['run', '-c', configPath];
          break;
        case KernelType.mihomo:
          args = ['-d', Directory(configPath).parent.path, '-f', configPath];
          break;
        case KernelType.v2Ray:
          args = ['run', '-config', configPath];
          break;
      }

      _logController.add('Starting ${type.name}...');
      _logController.add('Command: $kernelPath ${args.join(' ')}');

      _process = await Process.start(
        kernelPath,
        args,
        runInShell: true,
        environment: {
          if (type == KernelType.mihomo) 'GODEBUG': 'http2debug=0',
        },
      );

      _isRunning = true;
      
      // 监听 stdout
      _process!.stdout.transform(utf8.decoder).listen((data) {
        _logController.add('[${type.name}] $data');
      });

      // 监听 stderr
      _process!.stderr.transform(utf8.decoder).listen((data) {
        _logController.add('[${type.name}] ERROR: $data');
      });

      // 监听进程退出
      _process!.exitCode.then((code) {
        _isRunning = false;
        _logController.add('${type.name} exited with code: $code');
        _process = null;
      });

      _logController.add('${type.name} started successfully');
      return true;
    } catch (e) {
      _logController.add('Failed to start kernel: $e');
      _isRunning = false;
      _process = null;
      return false;
    }
  }

  /// 停止内核
  Future<bool> stop() async {
    if (!_isRunning || _process == null) {
      return true;
    }

    try {
      _logController.add('Stopping $_currentType...');
      
      if (Platform.isWindows) {
        // Windows: 使用 taskkill 强制终止
        await Process.run('taskkill', ['/F', '/PID', '${_process!.pid}']);
      } else {
        // Unix-like: 发送 SIGTERM
        _process!.kill(ProcessSignal.sigterm);
        
        // 等待 5 秒，如果还没退出则强制杀死
        await Future.delayed(const Duration(seconds: 5));
        if (_isRunning) {
          _process!.kill(ProcessSignal.sigkill);
        }
      }

      _isRunning = false;
      _logController.add('$_currentType stopped');
      return true;
    } catch (e) {
      _logController.add('Error stopping kernel: $e');
      return false;
    }
  }

  /// 重启内核
  Future<bool> restart({
    required String kernelPath,
    required KernelType type,
    required String configPath,
  }) async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 500));
    return await start(
      kernelPath: kernelPath,
      type: type,
      configPath: configPath,
    );
  }

  /// 检查内核是否可用
  static Future<bool> checkKernel(String path) async {
    try {
      final result = await Process.run(path, ['version']);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Check kernel failed: $e');
      return false;
    }
  }

  /// 获取内核版本
  static Future<String?> getVersion(String path) async {
    try {
      final result = await Process.run(path, ['version']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      debugPrint('Get version failed: $e');
    }
    return null;
  }

  /// 释放资源
  void dispose() {
    _logController.close();
  }
}
