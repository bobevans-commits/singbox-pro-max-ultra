import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// 平台通道控制器 - 用于与原生层通信
class KernelPlatformChannel {
  static const MethodChannel _methodChannel = MethodChannel('kernel_proxy');
  static const EventChannel _eventChannel = EventChannel('kernel_proxy/events');

  static final KernelPlatformChannel _instance = KernelPlatformChannel._internal();
  factory KernelPlatformChannel() => _instance;
  KernelPlatformChannel._internal();

  StreamSubscription? _eventSubscription;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// 获取事件流
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  /// 初始化事件监听
  void initEventListener() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((event) {
      if (event is Map) {
        _eventController.add(Map<String, dynamic>.from(event));
      }
    });
  }

  /// 启动内核
  Future<bool> startKernel({
    required String configPath,
    required String kernelType,
    bool tunMode = false,
    String? tunDeviceName,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('startKernel', {
        'configPath': configPath,
        'kernelType': kernelType,
        'tunMode': tunMode,
        'tunDeviceName': tunDeviceName,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('启动内核失败：${e.message}');
      return false;
    }
  }

  /// 停止内核
  Future<void> stopKernel() async {
    try {
      await _methodChannel.invokeMethod('stopKernel');
    } on PlatformException catch (e) {
      print('停止内核失败：${e.message}');
    }
  }

  /// 获取内核状态
  Future<Map<String, dynamic>?> getKernelStatus() async {
    try {
      final result = await _methodChannel.invokeMethod('getKernelStatus');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('获取状态失败：${e.message}');
      return null;
    }
  }

  /// 设置系统代理
  Future<bool> setSystemProxy({
    required bool enable,
    required String host,
    required int port,
    List<String>? bypassDomains,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('setSystemProxy', {
        'enable': enable,
        'host': host,
        'port': port,
        'bypassDomains': bypassDomains ?? [],
      });
      return result == true;
    } on PlatformException catch (e) {
      print('设置系统代理失败：${e.message}');
      return false;
    }
  }

  /// 启动 TUN 设备 (Android)
  Future<bool> startTunDevice({
    required String configPath,
    String deviceName = 'tun0',
    String ipAddress = '10.8.9.1',
    int mtu = 1500,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('startTunDevice', {
        'configPath': configPath,
        'deviceName': deviceName,
        'ipAddress': ipAddress,
        'mtu': mtu,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('启动 TUN 设备失败：${e.message}');
      return false;
    }
  }

  /// 停止 TUN 设备
  Future<void> stopTunDevice() async {
    try {
      await _methodChannel.invokeMethod('stopTunDevice');
    } on PlatformException catch (e) {
      print('停止 TUN 设备失败：${e.message}');
    }
  }

  /// 检查 VPN 权限 (仅 Android)
  Future<bool> checkVpnPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod('checkVpnPermission');
      return result == true;
    } on PlatformException catch (e) {
      print('检查 VPN 权限失败：${e.message}');
      return false;
    }
  }

  /// 请求 VPN 权限 (仅 Android)
  Future<bool> requestVpnPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod('requestVpnPermission');
      return result == true;
    } on PlatformException catch (e) {
      print('请求 VPN 权限失败：${e.message}');
      return false;
    }
  }

  /// 获取日志
  Future<List<String>> getLogs({int limit = 100}) async {
    try {
      final result = await _methodChannel.invokeMethod('getLogs', {'limit': limit});
      if (result is List) {
        return result.map((e) => e.toString()).toList();
      }
      return [];
    } on PlatformException catch (e) {
      print('获取日志失败：${e.message}');
      return [];
    }
  }

  /// 清除日志
  Future<void> clearLogs() async {
    try {
      await _methodChannel.invokeMethod('clearLogs');
    } on PlatformException catch (e) {
      print('清除日志失败：${e.message}');
    }
  }

  /// 释放资源
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}
