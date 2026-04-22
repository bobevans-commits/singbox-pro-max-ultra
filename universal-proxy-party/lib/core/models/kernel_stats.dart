import 'package:json_annotation/json_annotation.dart';

part 'kernel_stats.g.dart';

/// Statistics from a running kernel
@JsonSerializable()
class KernelStats {
  final int uploadSpeed;
  final int downloadSpeed;
  final int totalUpload;
  final int totalDownload;
  final int connectionCount;
  final DateTime? lastUpdated;

  KernelStats({
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.totalUpload,
    required this.totalDownload,
    required this.connectionCount,
    this.lastUpdated,
  });

  factory KernelStats.fromJson(Map<String, dynamic> json) =>
      _$KernelStatsFromJson(json);

  Map<String, dynamic> toJson() => _$KernelStatsToJson(this);

  KernelStats copyWith({
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
    int? connectionCount,
    DateTime? lastUpdated,
  }) {
    return KernelStats(
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      totalUpload: totalUpload ?? this.totalUpload,
      totalDownload: totalDownload ?? this.totalDownload,
      connectionCount: connectionCount ?? this.connectionCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Health status of a kernel
enum HealthStatus {
  healthy,
  unhealthy,
  unknown,
}

/// Connection information
@JsonSerializable()
class ConnectionInfo {
  final String id;
  final String protocol;
  final String sourceIP;
  final String destinationIP;
  final int uploadSpeed;
  final int downloadSpeed;
  final DateTime startTime;

  ConnectionInfo({
    required this.id,
    required this.protocol,
    required this.sourceIP,
    required this.destinationIP,
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.startTime,
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) =>
      _$ConnectionInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionInfoToJson(this);
}
