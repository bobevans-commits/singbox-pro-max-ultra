import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:universal_proxy_party/core/adapters/kernel_adapter.dart';
import 'package:universal_proxy_party/core/models/kernel_config.dart';
import 'package:universal_proxy_party/core/models/kernel_stats.dart';
import 'package:universal_proxy_party/core/models/kernel_error.dart';
import 'package:universal_proxy_party/utils/logger.dart';

/// Adapter for Mihomo (Clash) kernel
class MihomoAdapter extends KernelAdapter {
  Process? _process;
  bool _isRunning = false;

  MihomoAdapter({required super.config});

  @override
  Future<KernelResult<void>> start() async {
    try {
      if (_isRunning) {
        return KernelResult.err(
          'mihomo is already running',
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
          'mihomo binary not found',
          KernelErrorCode.binaryNotFound,
        );
      }

      AppLogger.info('Starting mihomo from: $binaryPath');
      AppLogger.info('Using config: ${config.configPath}');

      _process = await Process.start(
        binaryPath,
        ['-d', path.dirname(config.configPath), '-f', config.configPath],
        workingDirectory: path.dirname(binaryPath),
        runInShell: true,
      );

      // Listen to stdout and stderr
      _process!.stdout.transform(utf8.decoder).listen((data) {
        AppLogger.debug('mihomo: $data');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        AppLogger.error('mihomo error: $data');
      });

      // Wait a bit to check if process started successfully
      await Future.delayed(const Duration(milliseconds: 500));

      if (_process != null && _process!.exitCode.then((_) => false).timeout(
            const Duration(milliseconds: 100),
            onTimeout: () => true,
          )) {
        _isRunning = true;
        AppLogger.info('mihomo started successfully');
        return KernelResult.ok(null);
      } else {
        _isRunning = false;
        return KernelResult.err(
          'mihomo failed to start',
          KernelErrorCode.startFailed,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to start mihomo: $e');
      return KernelResult.err(
        'Failed to start mihomo: $e',
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
          'mihomo is not running',
          KernelErrorCode.stopFailed,
        );
      }

      AppLogger.info('Stopping mihomo...');
      
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
      AppLogger.info('mihomo stopped');
      
      return KernelResult.ok(null);
    } catch (e) {
      AppLogger.error('Failed to stop mihomo: $e');
      return KernelResult.err(
        'Failed to stop mihomo: $e',
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
          'mihomo is not running',
          KernelErrorCode.connectionRefused,
        );
      }

      // TODO: Implement actual stats fetching from Mihomo API
      // Mihomo provides REST API at http://localhost:{apiPort}
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

      // TODO: Add actual YAML validation for mihomo config
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
    final binaryName = Platform.isWindows ? 'clash.exe' : 'clash';
    
    // Try to find binary in common locations
    final possiblePaths = [
      // In bundled binaries directory
      path.join(Directory.current.path, 'binaries', Platform.operatingSystem, binaryName),
      // In system PATH
      binaryName,
      'mihomo',
      Platform.isWindows ? 'mihomo.exe' : 'mihomo',
    ];

    for (final p in possiblePaths) {
      if (await File(p).exists()) {
        return p;
      }
    }

    return null;
  }
}
