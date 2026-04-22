import 'dart:async';
import 'dart:io';
import '../models/kernel_info.dart';
import '../services/connection_state_manager.dart';
import '../services/traffic_statistics_service.dart';
import '../platform/kernel_platform_channel.dart';

/// TUN 模式服务
class TunService {
  static final TunService _instance = TunService._internal();
  factory TunService() => _instance;
  TunService._internal();

  bool _isEnabled = false;
  String? _deviceName;
  final _statusController = StreamController<bool>.broadcast();

  /// 获取 TUN 状态流
  Stream<bool> get statusStream => _statusController.stream;

  /// 是否启用
  bool get isEnabled => _isEnabled;

  /// 设备名称
  String? get deviceName => _deviceName;

  /// 启用 TUN 模式
  Future<bool> enable({
    required String configPath,
    KernelType kernelType = KernelType.singBox,
    String deviceName = 'tun0',
    String ipAddress = '10.8.9.1',
    int mtu = 1500,
  }) async {
    if (_isEnabled) {
      print('TUN 模式已启用');
      return true;
    }

    try {
      // Android 需要特殊处理
      if (Platform.isAndroid) {
        final channel = KernelPlatformChannel();
        
        // 检查并请求 VPN 权限
        final hasPermission = await channel.checkVpnPermission();
        if (!hasPermission) {
          final granted = await channel.requestVpnPermission();
          if (!granted) {
            ConnectionStateManager().setError('用户拒绝了 VPN 权限请求');
            return false;
          }
        }

        // 启动 TUN 设备
        final success = await channel.startTunDevice(
          configPath: configPath,
          deviceName: deviceName,
          ipAddress: ipAddress,
          mtu: mtu,
        );

        if (success) {
          _isEnabled = true;
          _deviceName = deviceName;
          _statusController.add(true);
          return true;
        } else {
          ConnectionStateManager().setError('启动 TUN 设备失败');
          return false;
        }
      } else {
        // 桌面平台：直接启动内核并启用 TUN
        final channel = KernelPlatformChannel();
        final success = await channel.startKernel(
          configPath: configPath,
          kernelType: kernelType.name,
          tunMode: true,
          tunDeviceName: deviceName,
        );

        if (success) {
          _isEnabled = true;
          _deviceName = deviceName;
          _statusController.add(true);
          return true;
        } else {
          ConnectionStateManager().setError('启动内核 TUN 模式失败');
          return false;
        }
      }
    } catch (e) {
      ConnectionStateManager().setError('TUN 模式错误：$e');
      return false;
    }
  }

  /// 禁用 TUN 模式
  Future<void> disable() async {
    if (!_isEnabled) return;

    try {
      final channel = KernelPlatformChannel();
      
      if (Platform.isAndroid) {
        await channel.stopTunDevice();
      }
      
      _isEnabled = false;
      _deviceName = null;
      _statusController.add(false);
    } catch (e) {
      print('禁用 TUN 模式失败：$e');
    }
  }

  /// 切换 TUN 模式
  Future<bool> toggle({
    required String configPath,
    KernelType kernelType = KernelType.singBox,
  }) async {
    if (_isEnabled) {
      await disable();
      return false;
    } else {
      return await enable(
        configPath: configPath,
        kernelType: kernelType,
      );
    }
  }

  /// 释放资源
  void dispose() {
    _statusController.close();
  }
}
