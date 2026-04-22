import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/config.dart';
import '../models/kernel_info.dart';
import '../utils/app_exceptions.dart';
import '../utils/platform_detector.dart';

/// 内核管理服务 - 负责多内核的下载、更新、切换和管理
class KernelManager extends ChangeNotifier {
  static final KernelManager _instance = KernelManager._internal();
  factory KernelManager() => _instance;
  KernelManager._internal();

  KernelType _selectedKernelType = KernelType.singBox;
  final Map<KernelType, KernelInfo> _kernels = {};
  final Map<KernelType, List<KernelRelease>> _releases = {};
  DownloadProgress? _currentDownload;
  String? _errorMessage;
  bool _isUpdating = false;

  // Getters
  KernelType get selectedKernelType => _selectedKernelType;
  Map<KernelType, KernelInfo> get kernels => Map.unmodifiable(_kernels);
  Map<KernelType, List<KernelRelease>> get releases => Map.unmodifiable(_releases);
  DownloadProgress? get currentDownload => _currentDownload;
  String? get errorMessage => _errorMessage;
  bool get isUpdating => _isUpdating;
  bool get isDownloading => _currentDownload != null;
  
  KernelInfo? get selectedKernel => _kernels[_selectedKernelType];
  bool get isCurrentKernelReady => 
      _kernels[_selectedKernelType]?.isDownloaded ?? false;

  /// 初始化内核管理器
  Future<void> initialize() async {
    await _loadKernels();
    await _checkForUpdates();
    notifyListeners();
  }

  /// 加载已安装的内核信息
  Future<void> _loadKernels() async {
    final appDir = await getApplicationDocumentsDirectory();
    final kernelDir = Directory('${appDir.path}/kernels');
    
    if (!await kernelDir.exists()) {
      await kernelDir.create(recursive: true);
    }

    // 初始化所有支持的内核类型
    for (var type in KernelType.values) {
      final kernelPath = '${kernelDir.path}/${_getKernelFileName(type)}';
      final file = File(kernelPath);
      
      _kernels[type] = KernelInfo(
        type: type,
        version: 'unknown',
        currentPath: await file.exists() ? kernelPath : null,
        isDownloaded: await file.exists(),
        supportedProtocols: _getSupportedProtocols(type),
      );
    }

    // 尝试获取已安装内核的版本信息
    await _detectInstalledVersions();
  }

  /// 检测已安装内核的版本
  Future<void> _detectInstalledVersions() async {
    for (var entry in _kernels.entries) {
      final info = entry.value;
      if (info.isDownloaded && info.currentPath != null) {
        try {
          // 实际应用中这里会执行内核二进制文件获取版本
          // 例如：Process.run(info.currentPath!, ['version'])
          _kernels[entry.key] = info.copyWith(
            version: '1.0.0', // 模拟版本号
            lastUpdated: await File(info.currentPath!).lastModified(),
          );
        } catch (e) {
          debugPrint('Failed to detect version for ${info.type.name}: $e');
        }
      }
    }
  }

  /// 获取支持的协议列表
  List<String> _getSupportedProtocols(KernelType type) {
    switch (type) {
      case KernelType.singBox:
        return [
          'VMess', 'VLESS', 'Trojan', 'Shadowsocks',
          'Hysteria', 'Hysteria2', 'TUIC', 'WireGuard',
        ];
      case KernelType.mihomo:
        return [
          'VMess', 'VLESS', 'Trojan', 'Shadowsocks',
          'Snell', 'Hysteria', 'Hysteria2', 'TUIC',
        ];
      case KernelType.v2Ray:
        return [
          'VMess', 'VLESS', 'Trojan', 'Shadowsocks',
          'Dokodemo', 'Freedom', 'Blackhole',
        ];
    }
  }

  /// 检查更新
  Future<void> _checkForUpdates() async {
    _isUpdating = true;
    notifyListeners();

    try {
      // 检查 sing-box 更新
      await _fetchReleases(KernelType.singBox);
      // 检查 mihomo 更新
      await _fetchReleases(KernelType.mihomo);
      // 检查 v2ray 更新
      await _fetchReleases(KernelType.v2Ray);
    } catch (e) {
      _errorMessage = 'Failed to check updates: $e';
      debugPrint(_errorMessage!);
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 从 GitHub 获取发布版本
  Future<void> _fetchReleases(KernelType type) async {
    final repoUrl = _getGithubRepoUrl(type);
    final url = Uri.parse('https://api.github.com/repos/$repoUrl/releases');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> releasesJson = jsonDecode(response.body);
        final releases = releasesJson
            .take(10) // 只保留最近 10 个版本
            .map((json) => KernelRelease(
                  version: json['tag_name']?.replaceAll('v', '') ?? '',
                  downloadUrl: '',
                  changelog: json['body'],
                  publishedAt: DateTime.parse(json['published_at']),
                  assets: (json['assets'] as List)
                      .map((a) => a['browser_download_url'] as String)
                      .toList(),
                ))
            .toList();
        
        _releases[type] = releases;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to fetch releases for ${type.name}: $e');
    }
  }

  /// 获取 GitHub 仓库 URL
  String _getGithubRepoUrl(KernelType type) {
    switch (type) {
      case KernelType.singBox:
        return 'SagerNet/sing-box';
      case KernelType.mihomo:
        return 'MetaCubeX/mihomo';
      case KernelType.v2Ray:
        return 'XTLS/Xray-core';
    }
  }

  /// 下载指定版本的内核
  Future<bool> downloadKernel({
    KernelType? type,
    String? version,
  }) async {
    final kernelType = type ?? _selectedKernelType;
    final releases = _releases[kernelType];
    
    if (releases == null || releases.isEmpty) {
      _errorMessage = 'No release information available for ${kernelType.name}';
      notifyListeners();
      return false;
    }
    
    final targetVersion = version ?? releases.first.version;

    if (targetVersion.isEmpty) {
      _errorMessage = 'No version specified or available';
      notifyListeners();
      return false;
    }

    _currentDownload = DownloadProgress(
      received: 0,
      total: 0,
      progress: 0.0,
      speed: '0 KB/s',
    );
    notifyListeners();

    try {
      final downloadUrl = _getDownloadUrl(kernelType, targetVersion);
      final appDir = await getApplicationDocumentsDirectory();
      final kernelDir = Directory('${appDir.path}/kernels');
      
      if (!await kernelDir.exists()) {
        await kernelDir.create(recursive: true);
      }

      final filePath = '${kernelDir.path}/${_getKernelFileName(kernelType)}';
      final file = File(filePath);
      final sink = file.openWrite();

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      var lastTime = DateTime.now();
      var lastBytes = 0;

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastTime).inMilliseconds;
        
        if (elapsed >= 500) { // 每 500ms 更新一次速度
          final speed = ((receivedBytes - lastBytes) * 1000 / elapsed);
          _currentDownload = DownloadProgress(
            received: receivedBytes,
            total: totalBytes,
            progress: totalBytes > 0 ? receivedBytes / totalBytes : 0,
            speed: _formatSpeed(speed),
          );
          lastTime = now;
          lastBytes = receivedBytes;
          notifyListeners();
        }
      });

      await sink.close();
      await client.close();

      // 设置可执行权限 (Unix-like 系统)
      if (!Platform.isWindows) {
        try {
          await Process.run('chmod', ['+x', filePath]);
        } catch (e) {
          debugPrint('Failed to set executable permission: $e');
        }
      }

      // 更新内核信息
      _kernels[kernelType] = KernelInfo(
        type: kernelType,
        version: targetVersion,
        currentPath: filePath,
        isDownloaded: true,
        lastUpdated: DateTime.now(),
        supportedProtocols: _getSupportedProtocols(kernelType),
      );

      _currentDownload = null;
      notifyListeners();
      return true;
    } on HttpException catch (e, stackTrace) {
      final error = NetworkException('Network error during download', e, stackTrace);
      _errorMessage = error.message;
      _currentDownload = null;
      notifyListeners();
      return false;
    } on SocketException catch (e, stackTrace) {
      final error = NetworkException('Connection failed', e, stackTrace);
      _errorMessage = error.message;
      _currentDownload = null;
      notifyListeners();
      return false;
    } on IOException catch (e, stackTrace) {
      final error = FileException('File operation failed', e, stackTrace);
      _errorMessage = error.message;
      _currentDownload = null;
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      final error = KernelException('Download failed: ${e.toString()}', e, stackTrace);
      _errorMessage = error.message;
      _currentDownload = null;
      notifyListeners();
      return false;
    }
  }

  /// 获取下载 URL
  /// 获取下载 URL
  String _getDownloadUrl(KernelType type, String version) {
    final platform = PlatformDetector.getPlatformName();
    final arch = PlatformDetector.getArchitecture();
    
    switch (type) {
      case KernelType.singBox:
        return 'https://github.com/SagerNet/sing-box/releases/download/v$version/sing-box-$version-$platform-$arch.tar.gz';
      case KernelType.mihomo:
        return 'https://github.com/MetaCubeX/mihomo/releases/download/v$version/mihomo-$platform-$arch-v$version.gz';
      case KernelType.v2Ray:
        return 'https://github.com/XTLS/Xray-core/releases/download/v$version/Xray-$platform-$arch.zip';
    }
  }

  /// 获取内核文件名
  String _getKernelFileName(KernelType type) {
    switch (type) {
      case KernelType.singBox:
        return Platform.isWindows ? 'sing-box.exe' : 'sing-box';
      case KernelType.mihomo:
        return Platform.isWindows ? 'mihomo.exe' : 'mihomo';
      case KernelType.v2Ray:
        return Platform.isWindows ? 'xray.exe' : 'xray';
    }
  }

  /// 格式化速度显示
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// 切换选中的内核类型
  Future<void> switchKernel(KernelType type) async {
    if (_selectedKernelType == type) return;
    
    if (!_kernels[type]!.isDownloaded) {
      _errorMessage = 'Kernel ${type.name} is not downloaded yet';
      notifyListeners();
      throw Exception('Kernel not downloaded');
    }

    _selectedKernelType = type;
    notifyListeners();
  }

  /// 删除已下载的内核
  Future<bool> deleteKernel(KernelType type) async {
    try {
      final info = _kernels[type];
      if (info?.currentPath != null) {
        final file = File(info!.currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      _kernels[type] = KernelInfo(
        type: type,
        version: 'unknown',
        isDownloaded: false,
        supportedProtocols: _getSupportedProtocols(type),
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete kernel: $e';
      notifyListeners();
      return false;
    }
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
