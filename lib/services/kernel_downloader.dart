import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../models/kernel_info.dart';
import '../models/config.dart';

/// 内核下载器服务 - 负责内核的下载、解压和安装
class KernelDownloader {
  static final KernelDownloader _instance = KernelDownloader._internal();
  factory KernelDownloader() => _instance;
  KernelDownloader._internal();

  final StreamController<DownloadProgress> _progressController = 
      StreamController<DownloadProgress>.broadcast();
  
  bool _isDownloading = false;
  String? _currentError;
  CancelToken? _cancelToken;

  Stream<DownloadProgress> get progressStream => _progressController.stream;
  bool get isDownloading => _isDownloading;
  String? get currentError => _currentError;

  /// 下载并安装内核
  Future<bool> downloadAndInstall({
    required KernelType type,
    required String version,
    String? platform,
    String? arch,
  }) async {
    if (_isDownloading) {
      _currentError = 'Another download is in progress';
      return false;
    }

    try {
      _isDownloading = true;
      _currentError = null;
      
      final targetPlatform = platform ?? _getCurrentPlatform();
      final targetArch = arch ?? _getCurrentArch();
      
      _progressController.add(DownloadProgress(
        received: 0,
        total: 0,
        progress: 0.0,
        speed: '准备下载...',
      ));

      // 获取下载 URL
      final downloadUrl = _getDownloadUrl(type, version, targetPlatform, targetArch);
      _progressController.add(DownloadProgress(
        received: 0,
        total: 0,
        progress: 0.01,
        speed: '正在连接...',
      ));

      // 创建 HTTP 客户端
      final client = http.Client();
      _cancelToken = CancelToken();
      
      try {
        final request = http.Request('GET', Uri.parse(downloadUrl));
        request.headers.addAll({
          'Accept': 'application/octet-stream',
        });
        
        final response = await client.send(request);
        
        if (response.statusCode != 200) {
          throw Exception('Download failed with status: ${response.statusCode}');
        }

        final totalBytes = response.contentLength ?? 0;
        var receivedBytes = 0;
        var lastTime = DateTime.now();
        var lastBytes = 0;

        // 获取应用目录
        final appDir = await getApplicationDocumentsDirectory();
        final kernelDir = Directory('${appDir.path}/kernels');
        if (!await kernelDir.exists()) {
          await kernelDir.create(recursive: true);
        }

        // 临时文件路径
        final tempFileName = '${type.name}_$version.tmp';
        final tempFilePath = '${kernelDir.path}/$tempFileName';
        final tempFile = File(tempFilePath);
        final sink = tempFile.openWrite();

        // 监听下载进度
        await for (final chunk in response.stream) {
          if (_cancelToken?.isCancelled == true) {
            await sink.close();
            await tempFile.delete();
            throw Exception('Download cancelled by user');
          }

          sink.add(chunk);
          receivedBytes += chunk.length;

          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;
          
          if (elapsed >= 500 || receivedBytes == totalBytes) {
            final speed = elapsed > 0 
                ? ((receivedBytes - lastBytes) * 1000 / elapsed)
                : 0;
            
            _progressController.add(DownloadProgress(
              received: receivedBytes,
              total: totalBytes,
              progress: totalBytes > 0 ? receivedBytes / totalBytes : 0,
              speed: _formatSpeed(speed),
            ));
            
            lastTime = now;
            lastBytes = receivedBytes;
          }
        }

        await sink.close();
        
        _progressController.add(DownloadProgress(
          received: receivedBytes,
          total: totalBytes,
          progress: 0.95,
          speed: '正在解压...',
        ));

        // 解压文件
        final extractedPath = await _extractFile(
          tempFile, 
          type, 
          targetPlatform,
        );
        
        // 删除临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        // 设置可执行权限
        if (!Platform.isWindows && await extractedPath.exists()) {
          final result = await Process.run('chmod', ['+x', extractedPath.path]);
          if (result.exitCode != 0) {
            debugPrint('Failed to set executable permission: ${result.stderr}');
          }
        }

        _progressController.add(DownloadProgress(
          received: receivedBytes,
          total: totalBytes,
          progress: 1.0,
          speed: '完成',
        ));

        await client.close();
        _isDownloading = false;
        return true;
        
      } catch (e) {
        await client.close();
        rethrow;
      }
    } catch (e) {
      _currentError = 'Download failed: $e';
      _isDownloading = false;
      _progressController.addError(e);
      return false;
    }
  }

  /// 解压下载的文件
  Future<File> _extractFile(
    File archiveFile,
    KernelType type,
    String platform,
  ) async {
    final filePath = archiveFile.path;
    final kernelDir = archiveFile.parent;
    
    final fileName = _getKernelFileName(type, platform);
    final outputPath = '${kernelDir.path}/$fileName';
    final outputFile = File(outputPath);

    // 如果是 .gz 文件
    if (filePath.endsWith('.gz')) {
      final bytes = await archiveFile.readAsBytes();
      final archive = GZipDecoder().decodeBytes(bytes);
      await outputFile.writeAsBytes(archive);
      return outputFile;
    }
    
    // 如果是 .zip 文件
    if (filePath.endsWith('.zip')) {
      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive.files) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.contains(type.name) || 
              name.endsWith('.exe') || 
              (platform != 'windows' && !name.contains('.'))) {
            final outFile = File('$outputPath');
            await outFile.writeAsBytes(file.content as List<int>);
            return outFile;
          }
        }
      }
      
      // 如果没有找到匹配的文件，使用第一个文件
      final firstFile = archive.files.firstWhere(
        (f) => f.isFile,
        orElse: () => archive.files.first,
      );
      final outFile = File(outputPath);
      await outFile.writeAsBytes(firstFile.content as List<int>);
      return outFile;
    }
    
    // 如果是 .tar.gz 文件
    if (filePath.endsWith('.tar.gz')) {
      final bytes = await archiveFile.readAsBytes();
      final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
      
      for (final file in archive.files) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.contains(type.name) || 
              name.endsWith('.exe') || 
              (platform != 'windows' && !name.contains('.'))) {
            final outFile = File(outputPath);
            await outFile.writeAsBytes(file.content as List<int>);
            return outFile;
          }
        }
      }
    }
    
    // 默认：直接复制文件
    await archiveFile.copy(outputPath);
    return outputFile;
  }

  /// 获取下载 URL
  String _getDownloadUrl(
    KernelType type,
    String version,
    String platform,
    String arch,
  ) {
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
  String _getKernelFileName(KernelType type, String platform) {
    switch (type) {
      case KernelType.singBox:
        return platform == 'windows' ? 'sing-box.exe' : 'sing-box';
      case KernelType.mihomo:
        return platform == 'windows' ? 'mihomo.exe' : 'mihomo';
      case KernelType.v2Ray:
        return platform == 'windows' ? 'xray.exe' : 'xray';
    }
  }

  /// 获取当前平台标识
  String _getCurrentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// 获取当前架构标识
  String _getCurrentArch() {
    final arch = Platform.localHostname.toLowerCase();
    if (arch.contains('x86') || arch.contains('amd64')) return 'amd64';
    if (arch.contains('arm') || arch.contains('aarch64')) {
      return Platform.isMacOS ? 'arm64' : 'arm64';
    }
    return 'amd64';
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

  /// 取消当前下载
  void cancelDownload() {
    _cancelToken?.cancel();
  }

  /// 清除错误
  void clearError() {
    _currentError = null;
  }

  /// 释放资源
  void dispose() {
    _progressController.close();
  }
}

/// 取消令牌
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  
  void cancel() {
    _isCancelled = true;
  }
}
