import 'package:flutter/foundation.dart';
import 'config.dart';

/// 内核信息模型
class KernelInfo {
  final KernelType type;
  final String version;
  final String? currentPath;
  final bool isDownloaded;
  final DateTime? lastUpdated;
  final List<String> supportedProtocols;

  KernelInfo({
    required this.type,
    required this.version,
    this.currentPath,
    this.isDownloaded = false,
    this.lastUpdated,
    this.supportedProtocols = const [],
  });

  factory KernelInfo.fromJson(Map<String, dynamic> json) {
    return KernelInfo(
      type: KernelTypeExtension.fromName(json['type'] ?? ''),
      version: json['version'] ?? '',
      currentPath: json['current_path'],
      isDownloaded: json['is_downloaded'] ?? false,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated']) 
          : null,
      supportedProtocols: (json['supported_protocols'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'version': version,
      'current_path': currentPath,
      'is_downloaded': isDownloaded,
      'last_updated': lastUpdated?.toIso8601String(),
      'supported_protocols': supportedProtocols,
    };
  }

  KernelInfo copyWith({
    KernelType? type,
    String? version,
    String? currentPath,
    bool? isDownloaded,
    DateTime? lastUpdated,
    List<String>? supportedProtocols,
  }) {
    return KernelInfo(
      type: type ?? this.type,
      version: version ?? this.version,
      currentPath: currentPath ?? this.currentPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      supportedProtocols: supportedProtocols ?? this.supportedProtocols,
    );
  }
}

/// 内核发布版本信息
class KernelRelease {
  final String version;
  final String downloadUrl;
  final String? changelog;
  final DateTime publishedAt;
  final List<String> assets;

  KernelRelease({
    required this.version,
    required this.downloadUrl,
    this.changelog,
    required this.publishedAt,
    this.assets = const [],
  });

  factory KernelRelease.fromJson(Map<String, dynamic> json) {
    return KernelRelease(
      version: json['version']?.replaceAll('v', '') ?? '',
      downloadUrl: json['download_url'] ?? '',
      changelog: json['changelog'],
      publishedAt: DateTime.parse(json['published_at']),
      assets: (json['assets'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'download_url': downloadUrl,
      'changelog': changelog,
      'published_at': publishedAt.toIso8601String(),
      'assets': assets,
    };
  }
}

/// 内核下载进度
class DownloadProgress {
  final int received;
  final int total;
  final double progress;
  final String speed;

  DownloadProgress({
    required this.received,
    required this.total,
    required this.progress,
    required this.speed,
  });

  @override
  String toString() {
    return 'DownloadProgress(${(progress * 100).toStringAsFixed(1)}%, $speed)';
  }
}
