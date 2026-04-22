import 'dart:async';
import '../models/kernel_info.dart';

/// 连接状态枚举
enum ConnectionState {
  disconnected, // 未连接
  connecting,   // 连接中
  connected,    // 已连接
  error,        // 错误
}

/// 连接状态详情
class ConnectionStatus {
  final ConnectionState state;
  final String? message;
  final KernelType? activeKernel;
  final DateTime? connectedAt;
  final int uploadSpeed; // bytes/s
  final int downloadSpeed; // bytes/s
  final int totalUpload; // bytes
  final int totalDownload; // bytes

  ConnectionStatus({
    this.state = ConnectionState.disconnected,
    this.message,
    this.activeKernel,
    this.connectedAt,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.totalUpload = 0,
    this.totalDownload = 0,
  });

  ConnectionStatus copyWith({
    ConnectionState? state,
    String? message,
    KernelType? activeKernel,
    DateTime? connectedAt,
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      activeKernel: activeKernel ?? this.activeKernel,
      connectedAt: connectedAt ?? this.connectedAt,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      totalUpload: totalUpload ?? this.totalUpload,
      totalDownload: totalDownload ?? this.totalDownload,
    );
  }

  /// 格式化速度显示
  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }

  /// 格式化流量显示
  static String formatTraffic(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(3)} GB';
    }
  }
}

/// 全局连接状态管理器
class ConnectionStateManager {
  static final ConnectionStateManager _instance = ConnectionStateManager._internal();
  factory ConnectionStateManager() => _instance;
  ConnectionStateManager._internal();

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _currentStatus = ConnectionStatus();

  /// 获取状态流
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// 获取当前状态
  ConnectionStatus get currentStatus => _currentStatus;

  /// 更新状态
  void updateStatus({
    ConnectionState? state,
    String? message,
    KernelType? activeKernel,
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
  }) {
    _currentStatus = _currentStatus.copyWith(
      state: state,
      message: message,
      activeKernel: activeKernel,
      connectedAt: state == ConnectionState.connected && _currentStatus.connectedAt == null
          ? DateTime.now()
          : _currentStatus.connectedAt,
      uploadSpeed: uploadSpeed,
      downloadSpeed: downloadSpeed,
      totalUpload: totalUpload,
      totalDownload: totalDownload,
    );

    if (!_statusController.isClosed) {
      _statusController.add(_currentStatus);
    }
  }

  /// 设置连接中状态
  void setConnecting(KernelType kernel) {
    updateStatus(
      state: ConnectionState.connecting,
      message: '正在启动 $kernel 内核...',
      activeKernel: kernel,
    );
  }

  /// 设置已连接状态
  void setConnected(KernelType kernel) {
    updateStatus(
      state: ConnectionState.connected,
      message: '已连接',
      activeKernel: kernel,
      connectedAt: DateTime.now(),
    );
  }

  /// 设置断开状态
  void setDisconnected() {
    updateStatus(
      state: ConnectionState.disconnected,
      message: '已断开连接',
      connectedAt: null,
      uploadSpeed: 0,
      downloadSpeed: 0,
    );
  }

  /// 设置错误状态
  void setError(String message) {
    updateStatus(
      state: ConnectionState.error,
      message: message,
    );
  }

  /// 更新流量统计
  void updateTraffic({
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
  }) {
    updateStatus(
      uploadSpeed: uploadSpeed,
      downloadSpeed: downloadSpeed,
      totalUpload: totalUpload,
      totalDownload: totalDownload,
    );
  }

  /// 重置流量统计
  void resetTraffic() {
    updateStatus(
      totalUpload: 0,
      totalDownload: 0,
      uploadSpeed: 0,
      downloadSpeed: 0,
    );
  }

  /// 释放资源
  void dispose() {
    _statusController.close();
  }
}
