// WebDAV 云同步服务
// 通过 WebDAV 协议实现配置的云端备份和恢复
// 支持上传备份、下载最新配置、连接测试

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// WebDAV 云同步服务 — 配置的云端备份与恢复
///
/// 职责：
/// - WebDAV 服务器连接配置和认证（Basic Auth）
/// - 连接测试（PROPFIND / MKCOL）
/// - 上传配置备份（带时间戳 + latest 双文件）
/// - 下载最新配置
/// - 序列化/反序列化连接配置
class WebDavSyncService extends ChangeNotifier {
  /// HTTP 客户端，用于 WebDAV 请求
  final Dio _dio = Dio();

  /// WebDAV 服务器地址
  String _serverUrl = '';

  /// WebDAV 用户名
  String _username = '';

  /// WebDAV 密码
  String _password = '';

  /// 远程存储路径，默认 /proxcore/
  String _remotePath = '/proxcore/';

  /// 是否正在同步中
  bool _isSyncing = false;

  /// 最后同步时间（ISO8601 格式）
  String? _lastSyncTime;

  /// 最近一次错误信息
  String? _error;

  // ---- 公开 Getter ----

  /// 是否已配置（服务器地址和用户名非空）
  bool get isConfigured => _serverUrl.isNotEmpty && _username.isNotEmpty;

  /// 是否正在同步中
  bool get isSyncing => _isSyncing;

  /// 最后同步时间
  String? get lastSyncTime => _lastSyncTime;

  /// 最近一次错误信息
  String? get error => _error;

  /// 配置 WebDAV 连接参数
  ///
  /// [serverUrl] WebDAV 服务器地址
  /// [username] 用户名
  /// [password] 密码
  /// [remotePath] 远程存储路径，默认 /proxcore/
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

  /// 测试 WebDAV 连接
  ///
  /// 尝试 PROPFIND 请求，207 表示成功
  /// 404 时尝试创建远程目录
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

  /// 上传配置到 WebDAV
  ///
  /// 上传两个文件：
  /// 1. proxcore_backup_{timestamp}.json — 带时间戳的备份
  /// 2. proxcore_latest.json — 最新配置（覆盖写入）
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

  /// 从 WebDAV 下载最新配置
  ///
  /// 下载 proxcore_latest.json 文件内容
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

  /// 创建远程目录（MKCOL 方法）
  ///
  /// 405 状态码表示目录已存在，忽略该错误
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

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'server_url': _serverUrl,
        'username': _username,
        'password': _password,
        'remote_path': _remotePath,
        'last_sync_time': _lastSyncTime,
      };

  /// 从 JSON 反序列化并自动配置连接
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
