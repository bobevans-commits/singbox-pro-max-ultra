import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class WebDavSyncService extends ChangeNotifier {
  final Dio _dio = Dio();

  String _serverUrl = '';
  String _username = '';
  String _password = '';
  String _remotePath = '/proxcore/';
  bool _isSyncing = false;
  String? _lastSyncTime;
  String? _error;

  bool get isConfigured => _serverUrl.isNotEmpty && _username.isNotEmpty;
  bool get isSyncing => _isSyncing;
  String? get lastSyncTime => _lastSyncTime;
  String? get error => _error;

  void configure({
    required String serverUrl,
    required String username,
    required String password,
    String remotePath = '/proxcore/',
  }) {
    _serverUrl = serverUrl.replaceAll(RegExp(r'/$'), '');
    _username = username;
    _password = password;
    _remotePath = remotePath.startsWith('/') ? remotePath : '/$remotePath';

    _dio.options.baseUrl = _serverUrl;
    _dio.options.headers['Authorization'] =
        'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
  }

  Future<bool> testConnection() async {
    try {
      await _dio.request(
        _remotePath,
        options: Options(method: 'PROPFIND'),
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 207) return true;
      if (e.response?.statusCode == 404) {
        try {
          await _createDirectory(_remotePath);
          return true;
        } catch (_) {
          return false;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadConfig(String configJson) async {
    if (!isConfigured) return false;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      await _createDirectory(_remotePath);

      final filename = 'proxcore_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      await _dio.put(
        '$_remotePath$filename',
        data: configJson,
        options: Options(contentType: 'application/json'),
      );

      await _dio.put(
        '${_remotePath}proxcore_latest.json',
        data: configJson,
        options: Options(contentType: 'application/json'),
      );

      _lastSyncTime = DateTime.now().toIso8601String();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '上传失败: $e';
      _isSyncing = false;
      debugPrint('[WebDav] Upload failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<String?> downloadLatestConfig() async {
    if (!isConfigured) return null;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.get<String>(
        '${_remotePath}proxcore_latest.json',
        options: Options(responseType: ResponseType.plain),
      );

      _lastSyncTime = DateTime.now().toIso8601String();
      _isSyncing = false;
      notifyListeners();
      return resp.data;
    } catch (e) {
      _error = '下载失败: $e';
      _isSyncing = false;
      debugPrint('[WebDav] Download failed: $e');
      notifyListeners();
      return null;
    }
  }

  Future<void> _createDirectory(String path) async {
    try {
      await _dio.request(
        path,
        options: Options(method: 'MKCOL'),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 405) rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'server_url': _serverUrl,
        'username': _username,
        'password': _password,
        'remote_path': _remotePath,
        'last_sync_time': _lastSyncTime,
      };

  void loadFromJson(Map<String, dynamic> json) {
    _serverUrl = json['server_url'] as String? ?? '';
    _username = json['username'] as String? ?? '';
    _password = json['password'] as String? ?? '';
    _remotePath = json['remote_path'] as String? ?? '/proxcore/';
    _lastSyncTime = json['last_sync_time'] as String?;

    if (isConfigured) {
      configure(
        serverUrl: _serverUrl,
        username: _username,
        password: _password,
        remotePath: _remotePath,
      );
    }
  }
}
