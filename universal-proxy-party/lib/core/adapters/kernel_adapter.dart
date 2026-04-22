import 'package:universal_proxy_party/core/models/kernel_config.dart';
import 'package:universal_proxy_party/core/models/kernel_stats.dart';
import 'package:universal_proxy_party/core/models/kernel_error.dart';

/// Abstract interface for all kernel adapters
/// 
/// This trait defines the contract that all kernel implementations must follow,
/// allowing the UI to interact with different kernels (sing-box, v2ray, mihomo)
/// through a unified interface.
abstract class KernelAdapter {
  final KernelConfig config;

  KernelAdapter({required this.config});

  /// Start the kernel process
  /// 
  /// Returns [KernelResult] indicating success or failure
  Future<KernelResult<void>> start();

  /// Stop the running kernel process
  /// 
  /// Returns [KernelResult] indicating success or failure
  Future<KernelResult<void>> stop();

  /// Restart the kernel process
  /// 
  /// This should be equivalent to calling stop() then start()
  Future<KernelResult<void>> restart();

  /// Fetch current statistics from the kernel
  /// 
  /// Returns traffic stats, connection count, etc.
  Future<KernelResult<KernelStats>> fetchStats();

  /// Perform a health check on the kernel
  /// 
  /// Verifies if the kernel is running and responsive
  Future<KernelResult<HealthStatus>> healthCheck();

  /// Validate the configuration file
  /// 
  /// Checks if the config file exists and is valid for this kernel type
  Future<KernelResult<bool>> validateConfig();

  /// Get the current running state
  bool get isRunning;

  /// Get the kernel type this adapter handles
  KernelType get kernelType => config.type;

  /// Cleanup resources when adapter is disposed
  void dispose();
}
