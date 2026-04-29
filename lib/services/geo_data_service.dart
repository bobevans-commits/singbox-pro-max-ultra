// GeoIP/GeoSite 数据服务
// 负责下载和更新 sing-geoip.db / sing-geosite.db 地理数据文件
// 用于智能分流规则中的 GeoIP 和 GeoSite 匹配

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// GeoIP/GeoSite 数据服务 — 地理数据文件管理
///
/// 职责：
/// - 检查本地 geoip.db / geosite.db 版本（文件修改日期）
/// - 从 GitHub 下载最新地理数据文件
/// - 提供数据文件路径供内核配置引用
class GeoDataService extends ChangeNotifier {
  /// HTTP 客户端，用于下载地理数据文件
  final Dio _dio = Dio();

  /// 本地 geoip.db 版本（文件修改日期字符串）
  String? _geoipVersion;

  /// 本地 geosite.db 版本（文件修改日期字符串）
  String? _geositeVersion;

  /// 是否正在更新中
  bool _updating = false;

  /// 最近一次错误信息
  String? _error;

  // ---- 公开 Getter ----

  /// 本地 geoip.db 版本
  String? get geoipVersion => _geoipVersion;

  /// 本地 geosite.db 版本
  String? get geositeVersion => _geositeVersion;

  /// 是否正在更新中
  bool get isUpdating => _updating;

  /// 最近一次错误信息
  String? get error => _error;

  /// 地理数据文件存储目录
  ///
  /// 路径：{应用支持目录}/geo/
  Future<String> get _dataDir async {
    final dir = await getApplicationSupportDirectory();
    final dataDir = Directory('${dir.path}/geo');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir.path;
  }

  /// 初始化，检查本地地理数据文件版本
  Future<void> init() async {
    await checkLocalVersions();
  }

  /// 检查本地地理数据文件版本
  ///
  /// 使用文件修改日期作为版本标识
  Future<void> checkLocalVersions() async {
    final dir = await _dataDir;

    final geoipFile = File('$dir/geoip.db');
    if (await geoipFile.exists()) {
      final stat = await geoipFile.stat();
      _geoipVersion = _formatDate(stat.modified);
    }

    final geositeFile = File('$dir/geosite.db');
    if (await geositeFile.exists()) {
      final stat = await geositeFile.stat();
      _geositeVersion = _formatDate(stat.modified);
    }

    notifyListeners();
  }

  /// 更新所有地理数据文件
  ///
  /// 从 GitHub SagerNet 仓库下载最新的 geoip.db 和 geosite.db
  Future<void> updateAll() async {
    if (_updating) return;
    _updating = true;
    _error = null;
    notifyListeners();

    try {
      await _downloadFile(
        'https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db',
        'geoip.db',
      );
      await _downloadFile(
        'https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db',
        'geosite.db',
      );
      await checkLocalVersions();
    } catch (e) {
      _error = '更新失败: $e';
      debugPrint('[GeoData] Update failed: $e');
    }

    _updating = false;
    notifyListeners();
  }

  /// 下载单个地理数据文件
  ///
  /// [url] 下载地址
  /// [filename] 目标文件名
  Future<void> _downloadFile(String url, String filename) async {
    final dir = await _dataDir;
    final filePath = '$dir/$filename';

    await _dio.download(
      url,
      filePath,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
  }

  /// 获取 geoip.db 文件路径
  ///
  /// 文件不存在时返回 null
  Future<String?> getGeoipPath() async {
    final dir = await _dataDir;
    final file = File('$dir/geoip.db');
    return await file.exists() ? file.path : null;
  }

  /// 获取 geosite.db 文件路径
  ///
  /// 文件不存在时返回 null
  Future<String?> getGeositePath() async {
    final dir = await _dataDir;
    final file = File('$dir/geosite.db');
    return await file.exists() ? file.path : null;
  }

  /// 格式化日期为 YYYY-MM-DD 字符串
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
