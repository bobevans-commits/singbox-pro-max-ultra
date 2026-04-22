import 'dart:async';
import '../models/kernel_info.dart';
import 'connection_state_manager.dart';

/// 流量统计服务
class TrafficStatisticsService {
  static final TrafficStatisticsService _instance = TrafficStatisticsService._internal();
  factory TrafficStatisticsService() => _instance;
  TrafficStatisticsService._internal();

  final _trafficController = StreamController<TrafficData>.broadcast();
  
  // 实时速度 (bytes/s)
  int _currentUploadSpeed = 0;
  int _currentDownloadSpeed = 0;
  
  // 总流量 (bytes)
  int _totalUpload = 0;
  int _totalDownload = 0;
  
  // 历史数据 (用于图表，保留最近 60 秒)
  final List<TrafficDataPoint> _history = [];
  static const int maxHistoryPoints = 60;
  
  Timer? _updateTimer;
  bool _isRunning = false;

  /// 获取流量数据流
  Stream<TrafficData> get trafficStream => _trafficController.stream;

  /// 获取当前流量数据
  TrafficData get currentTraffic => TrafficData(
    uploadSpeed: _currentUploadSpeed,
    downloadSpeed: _currentDownloadSpeed,
    totalUpload: _totalUpload,
    totalDownload: _totalDownload,
    history: List.unmodifiable(_history),
  );

  /// 是否正在统计
  bool get isRunning => _isRunning;

  /// 开始统计
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitUpdate();
    });
  }

  /// 停止统计
  void stop() {
    _isRunning = false;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// 重置流量统计
  void reset() {
    _currentUploadSpeed = 0;
    _currentDownloadSpeed = 0;
    _totalUpload = 0;
    _totalDownload = 0;
    _history.clear();
    _emitUpdate();
  }

  /// 更新流量数据 (由内核执行器调用)
  void update({
    required int uploadSpeed,
    required int downloadSpeed,
    int? totalUpload,
    int? totalDownload,
  }) {
    _currentUploadSpeed = uploadSpeed;
    _currentDownloadSpeed = downloadSpeed;
    
    if (totalUpload != null) _totalUpload = totalUpload;
    if (totalDownload != null) _totalDownload = totalDownload;
    
    // 累加模式：如果没有提供总量，则根据速度累加
    if (totalUpload == null) {
      _totalUpload += uploadSpeed;
    }
    if (totalDownload == null) {
      _totalDownload += downloadSpeed;
    }
    
    _emitUpdate();
  }

  void _emitUpdate() {
    final now = DateTime.now();
    final dataPoint = TrafficDataPoint(
      timestamp: now,
      uploadSpeed: _currentUploadSpeed,
      downloadSpeed: _currentDownloadSpeed,
    );
    
    _history.add(dataPoint);
    if (_history.length > maxHistoryPoints) {
      _history.removeAt(0);
    }
    
    final data = TrafficData(
      uploadSpeed: _currentUploadSpeed,
      downloadSpeed: _currentDownloadSpeed,
      totalUpload: _totalUpload,
      totalDownload: _totalDownload,
      history: List.unmodifiable(_history),
    );
    
    if (!_trafficController.isClosed) {
      _trafficController.add(data);
    }
    
    // 同步到连接状态管理器
    ConnectionStateManager().updateTraffic(
      uploadSpeed: _currentUploadSpeed,
      downloadSpeed: _currentDownloadSpeed,
      totalUpload: _totalUpload,
      totalDownload: _totalDownload,
    );
  }

  /// 释放资源
  void dispose() {
    stop();
    _trafficController.close();
  }
}

/// 流量数据包
class TrafficData {
  final int uploadSpeed;
  final int downloadSpeed;
  final int totalUpload;
  final int totalDownload;
  final List<TrafficDataPoint> history;

  TrafficData({
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.totalUpload,
    required this.totalDownload,
    required this.history,
  });

  /// 格式化上传速度
  String get uploadSpeedText => _formatSpeed(uploadSpeed);

  /// 格式化下载速度
  String get downloadSpeedText => _formatSpeed(downloadSpeed);

  /// 格式化总上传
  String get totalUploadText => _formatTraffic(totalUpload);

  /// 格式化总下载
  String get totalDownloadText => _formatTraffic(totalDownload);

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }

  String _formatTraffic(int bytes) {
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

/// 流量数据点 (用于图表)
class TrafficDataPoint {
  final DateTime timestamp;
  final int uploadSpeed;
  final int downloadSpeed;

  TrafficDataPoint({
    required this.timestamp,
    required this.uploadSpeed,
    required this.downloadSpeed,
  });
}
