import 'package:flutter/foundation.dart';
import 'package:universal_proxy_party/core/adapters/kernel_adapter.dart';
import 'package:universal_proxy_party/core/adapters/singbox_adapter.dart';
import 'package:universal_proxy_party/core/adapters/mihomo_adapter.dart';
import 'package:universal_proxy_party/core/adapters/v2ray_adapter.dart';
import 'package:universal_proxy_party/core/models/kernel_config.dart';
import 'package:universal_proxy_party/core/models/kernel_stats.dart';
import 'package:universal_proxy_party/core/models/kernel_error.dart';
import 'package:universal_proxy_party/utils/logger.dart';

/// Manages kernel lifecycle and adapter selection
class KernelManager extends ChangeNotifier {
  KernelAdapter? _activeAdapter;
  KernelConfig? _activeConfig;
  KernelStats? _currentStats;
  bool _isInitializing = false;

  KernelAdapter? get activeAdapter => _activeAdapter;
  KernelConfig? get activeConfig => _activeConfig;
  KernelStats? get currentStats => _currentStats;
  bool get isRunning => _activeAdapter?.isRunning ?? false;
  bool get isInitializing => _isInitializing;

  /// Create an adapter for the specified kernel type
  KernelAdapter createAdapter(KernelConfig config) {
    switch (config.type) {
      case KernelType.singBox:
        return SingBoxAdapter(config: config);
      case KernelType.mihomo:
        return MihomoAdapter(config: config);
      case KernelType.v2Ray:
        return V2RayAdapter(config: config);
    }
  }

  /// Start a kernel with the given configuration
  Future<KernelResult<void>> startKernel(KernelConfig config) async {
    try {
      _isInitializing = true;
      notifyListeners();

      // Stop existing kernel if running
      if (_activeAdapter != null && _activeAdapter!.isRunning) {
        await stopKernel();
      }

      // Create new adapter
      _activeAdapter = createAdapter(config);
      _activeConfig = config;

      // Start the kernel
      final result = await _activeAdapter!.start();
      
      if (result.success) {
        AppLogger.info('Kernel started successfully: ${config.type.name}');
        _startStatsPolling();
      } else {
        _activeAdapter = null;
        _activeConfig = null;
      }

      _isInitializing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isInitializing = false;
      _activeAdapter = null;
      _activeConfig = null;
      notifyListeners();
      return KernelResult.err(
        'Failed to start kernel: $e',
        KernelErrorCode.startFailed,
        e,
      );
    }
  }

  /// Stop the currently running kernel
  Future<KernelResult<void>> stopKernel() async {
    try {
      if (_activeAdapter == null || !_activeAdapter!.isRunning) {
        return KernelResult.ok(null);
      }

      _stopStatsPolling();
      
      final result = await _activeAdapter!.stop();
      
      if (result.success) {
        AppLogger.info('Kernel stopped successfully');
        _activeAdapter?.dispose();
        _activeAdapter = null;
        _activeConfig = null;
        _currentStats = null;
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      AppLogger.error('Failed to stop kernel: $e');
      return KernelResult.err(
        'Failed to stop kernel: $e',
        KernelErrorCode.stopFailed,
        e,
      );
    }
  }

  /// Restart the currently running kernel
  Future<KernelResult<void>> restartKernel() async {
    if (_activeAdapter == null || _activeConfig == null) {
      return KernelResult.err(
        'No kernel is running',
        KernelErrorCode.restartFailed,
      );
    }

    return startKernel(_activeConfig!);
  }

  /// Perform health check on the running kernel
  Future<KernelResult<HealthStatus>> healthCheck() async {
    if (_activeAdapter == null) {
      return KernelResult.ok(HealthStatus.unknown);
    }

    return _activeAdapter!.healthCheck();
  }

  /// Validate configuration without starting the kernel
  Future<KernelResult<bool>> validateConfig(KernelConfig config) async {
    final adapter = createAdapter(config);
    final result = await adapter.validateConfig();
    adapter.dispose();
    return result;
  }

  /// Get current traffic statistics
  Future<KernelStats?> fetchStats() async {
    if (_activeAdapter == null || !_activeAdapter!.isRunning) {
      return null;
    }

    final result = await _activeAdapter!.fetchStats();
    if (result.success) {
      _currentStats = result.data;
      notifyListeners();
      return _currentStats;
    }

    return null;
  }

  // Stats polling
  bool _isPolling = false;
  
  void _startStatsPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    _pollStats();
  }

  void _stopStatsPolling() {
    _isPolling = false;
  }

  Future<void> _pollStats() async {
    while (_isPolling && _activeAdapter != null && _activeAdapter!.isRunning) {
      await fetchStats();
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    _stopStatsPolling();
    _activeAdapter?.dispose();
    super.dispose();
  }
}
