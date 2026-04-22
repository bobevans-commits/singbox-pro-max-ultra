import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:universal_proxy_party/core/adapters/kernel_adapter.dart';
import 'package:universal_proxy_party/core/models/kernel_config.dart';
import 'package:universal_proxy_party/core/models/kernel_stats.dart';
import 'package:universal_proxy_party/core/models/kernel_error.dart';
import 'package:universal_proxy_party/utils/logger.dart';

/// Adapter for sing-box kernel
class SingBoxAdapter extends KernelAdapter {
  Process? _process;
  bool _isRunning = false;

  SingBoxAdapter({required super.config});

  @override
  Future<KernelResult<void>> start() async {
    try {
      if (_isRunning) {
        return KernelResult.err(
          'sing-box is already running',
          KernelErrorCode.startFailed,
        );
      }

      // Validate config first
      final validateResult = await validateConfig();
      if (!validateResult.success) {
        return validateResult as KernelResult<void>;
      }

      final binaryPath = await _getBinaryPath();
      if (binaryPath == null) {
        return KernelResult.err(
          'sing-box binary not found',
          KernelErrorCode.binaryNotFound,
        );
      }

      AppLogger.info('Starting sing-box from: $binaryPath');
      AppLogger.info('Using config: ${config.configPath}');

      _process = await Process.start(
        binaryPath,
        ['run', '-c', config.configPath],
        workingDirectory: path.dirname(binaryPath),
        runInShell: true,
      );

      // Listen to stdout and stderr
      _process!.stdout.transform(utf8.decoder).listen((data) {
        AppLogger.debug('sing-box: $data');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        AppLogger.error('sing-box error: $data');
      });

      // Wait a bit to check if process started successfully
      await Future.delayed(const Duration(milliseconds: 500));

      if (_process != null && _process!.exitCode.then((_) => false).timeout(
            const Duration(milliseconds: 100),
            onTimeout: () => true,
          )) {
        _isRunning = true;
        AppLogger.info('sing-box started successfully');
        return KernelResult.ok(null);
      } else {
        _isRunning = false;
        return KernelResult.err(
          'sing-box failed to start',
          KernelErrorCode.startFailed,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to start sing-box: $e');
      return KernelResult.err(
        'Failed to start sing-box: $e',
        KernelErrorCode.startFailed,
        e,
      );
    }
  }

  @override
  Future<KernelResult<void>> stop() async {
    try {
      if (!_isRunning || _process == null) {
        return KernelResult.err(
          'sing-box is not running',
          KernelErrorCode.stopFailed,
        );
      }

      AppLogger.info('Stopping sing-box...');
      
      // Send SIGTERM first
      _process!.kill(ProcessSignal.sigterm);

      // Wait for graceful shutdown
      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLogger.warn('Graceful shutdown timed out, forcing kill');
          _process!.kill(ProcessSignal.sigkill);
        },
      );

      _process = null;
      _isRunning = false;
      AppLogger.info('sing-box stopped');
      
      return KernelResult.ok(null);
    } catch (e) {
      AppLogger.error('Failed to stop sing-box: $e');
      return KernelResult.err(
        'Failed to stop sing-box: $e',
        KernelErrorCode.stopFailed,
        e,
      );
    }
  }

  @override
  Future<KernelResult<void>> restart() async {
    await stop();
    return start();
  }

  @override
  Future<KernelResult<KernelStats>> fetchStats() async {
    try {
      if (!_isRunning) {
        return KernelResult.err(
          'sing-box is not running',
          KernelErrorCode.connectionRefused,
        );
      }

      // TODO: Implement actual stats fetching from sing-box API
      // This is a placeholder implementation
      return KernelResult.ok(KernelStats(
        uploadSpeed: 0,
        downloadSpeed: 0,
        totalUpload: 0,
        totalDownload: 0,
        connectionCount: 0,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      AppLogger.error('Failed to fetch stats: $e');
      return KernelResult.err(
        'Failed to fetch stats: $e',
        KernelErrorCode.connectionRefused,
        e,
      );
    }
  }

  @override
  Future<KernelResult<HealthStatus>> healthCheck() async {
    try {
      if (!_isRunning || _process == null) {
        return KernelResult.ok(HealthStatus.unknown);
      }

      // Check if process is still alive
      try {
        final exitCode = await _process!.exitCode.timeout(
          const Duration(milliseconds: 100),
        );
        if (exitCode != null) {
          _isRunning = false;
          return KernelResult.ok(HealthStatus.unhealthy);
        }
      } on TimeoutException {
        // Process is still running
        return KernelResult.ok(HealthStatus.healthy);
      }

      return KernelResult.ok(HealthStatus.healthy);
    } catch (e) {
      AppLogger.error('Health check failed: $e');
      return KernelResult.err(
        'Health check failed: $e',
        KernelErrorCode.unknown,
        e,
      );
    }
  }

  @override
  Future<KernelResult<bool>> validateConfig() async {
    try {
      final file = File(config.configPath);
      if (!await file.exists()) {
        return KernelResult.err(
          'Config file not found: ${config.configPath}',
          KernelErrorCode.configInvalid,
        );
      }

      // TODO: Add actual JSON validation for sing-box config
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return KernelResult.err(
          'Config file is empty',
          KernelErrorCode.configInvalid,
        );
      }

      return KernelResult.ok(true);
    } catch (e) {
      AppLogger.error('Config validation failed: $e');
      return KernelResult.err(
        'Config validation failed: $e',
        KernelErrorCode.configInvalid,
        e,
      );
    }
  }

  @override
  bool get isRunning => _isRunning;

  @override
  void dispose() {
    if (_isRunning) {
      stop();
    }
  }

  Future<String?> _getBinaryPath() async {
    // Try to find binary in common locations
    final possiblePaths = [
      // In bundled binaries directory
      path.join(Directory.current.path, 'binaries', Platform.operatingSystem, 'sing-box'),
      path.join(Directory.current.path, 'binaries', Platform.operatingSystem, 'sing-box.exe'),
      // In system PATH
      'sing-box',
    ];

    for (final p in possiblePaths) {
      if (Platform.isWindows && !p.endsWith('.exe') && !p.contains('/')) {
        p += '.exe';
      }
      
      if (await File(p).exists()) {
        return p;
      }

      // Try with .exe on Windows
      if (Platform.isWindows && !p.endsWith('.exe')) {
        final exePath = '$p.exe';
        if (await File(exePath).exists()) {
          return exePath;
        }
      }
    }

    return null;
  }
}
