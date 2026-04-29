import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class GeoDataService extends ChangeNotifier {
  final Dio _dio = Dio();

  String? _geoipVersion;
  String? _geositeVersion;
  bool _updating = false;
  String? _error;

  String? get geoipVersion => _geoipVersion;
  String? get geositeVersion => _geositeVersion;
  bool get isUpdating => _updating;
  String? get error => _error;

  Future<String> get _dataDir async {
    final dir = await getApplicationSupportDirectory();
    final dataDir = Directory('${dir.path}/geo');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir.path;
  }

  Future<void> init() async {
    await checkLocalVersions();
  }

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

  Future<void> _downloadFile(String url, String filename) async {
    final dir = await _dataDir;
    final filePath = '$dir/$filename';

    await _dio.download(
      url,
      filePath,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
  }

  Future<String?> getGeoipPath() async {
    final dir = await _dataDir;
    final file = File('$dir/geoip.db');
    return await file.exists() ? file.path : null;
  }

  Future<String?> getGeositePath() async {
    final dir = await _dataDir;
    final file = File('$dir/geosite.db');
    return await file.exists() ? file.path : null;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
