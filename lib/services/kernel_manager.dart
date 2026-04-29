// 内核管理器
// 负责代理内核（sing-box / mihomo / v2ray）的完整生命周期管理
// 包括：安装检测、版本查询、下载安装、解压部署、删除卸载

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../models/config.dart';
import '../models/kernel_info.dart';

/// 内核管理器 — 管理代理内核的安装、下载、版本和生命周期
///
/// 职责：
/// - 检测本地已安装的内核二进制文件
/// - 从 GitHub Releases 查询最新版本和发布列表
/// - 下载内核压缩包（.zip / .gz）并自动解压安装
/// - 设置可执行权限（Linux/macOS chmod +x）
/// - 删除已安装的内核
/// - 自动识别当前平台和架构（amd64 / arm64）
class KernelManager extends ChangeNotifier {
  /// 已安装内核信息映射，键为内核类型
  final Map<KernelType, KernelInfo> _kernels = {};

  /// 内核状态映射，键为内核类型
  final Map<KernelType, KernelStatus> _statusMap = {};

  /// 内核版本映射，键为内核类型
  final Map<KernelType, String> _versionMap = {};

  /// 最近一次错误信息
  String? _error;

  // ---- 公开 Getter ----

  /// 已安装内核信息映射（不可变）
  Map<KernelType, KernelInfo> get kernels => Map.unmodifiable(_kernels);

  /// 内核状态映射（不可变）
  Map<KernelType, KernelStatus> get statusMap => Map.unmodifiable(_statusMap);

  /// 最近一次错误信息
  String? get error => _error;

  /// 获取指定内核类型的安装状态
  KernelStatus getStatus(KernelType type) =>
      _statusMap[type] ?? KernelStatus.notInstalled;

  /// 获取指定内核类型的版本号
  String? getVersion(KernelType type) => _versionMap[type];

  /// 检查指定内核是否已安装
  bool isInstalled(KernelType type) {
    final status = _statusMap[type];
    return status == KernelStatus.installed || status == KernelStatus.running;
  }

  /// 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 获取指定内核类型的二进制文件名
  ///
  /// Windows 平台自动追加 .exe 后缀
  String getBinaryName(KernelType type) {
    final ext = Platform.isWindows ? '.exe' : '';
    switch (type) {
      case KernelType.singbox:
        return 'sing-box$ext';
      case KernelType.mihomo:
        return 'mihomo$ext';
      case KernelType.v2ray:
        return 'xray$ext';
    }
  }

  /// 获取指定内核类型的二进制文件完整路径
  ///
  /// 优先使用 KernelInfo 中记录的路径，否则使用默认路径
  Future<String> getBinaryPath(KernelType type) async {
    final kernelInfo = _kernels[type];
    if (kernelInfo != null && kernelInfo.binaryPath.isNotEmpty) {
      return kernelInfo.binaryPath;
    }
    final dir = await getKernelDir();
    return '${dir.path}/${getBinaryName(type)}';
  }

  /// 初始化内核管理器，检测所有内核类型的安装状态
  Future<void> init() async {
    for (final type in KernelType.values) {
      _statusMap[type] = KernelStatus.notInstalled;
      await _checkInstalled(type);
    }
    notifyListeners();
  }

  /// 检测指定内核类型是否已安装
  ///
  /// 在 assets/bin 目录下查找对应的二进制文件
  Future<void> _checkInstalled(KernelType type) async {
    try {
      final dir = await getKernelDir();
      final binaryName = getBinaryName(type);
      final binaryFile = File('${dir.path}/$binaryName');

      if (await binaryFile.exists()) {
        _statusMap[type] = KernelStatus.installed;
        _kernels[type] = KernelInfo(
          type: type,
          binaryPath: binaryFile.path,
          version: await _readInstalledVersion(type),
        );
        _versionMap[type] = _kernels[type]!.version;
      }
    } catch (e) {
      debugPrint('KernelManager: check installed error for ${type.name}: $e');
    }
  }

  /// 从 GitHub Releases API 获取指定内核的最新版本号
  ///
  /// 调用 https://api.github.com/repos/{repo}/releases/latest
  /// 返回 tag_name（去掉 'v' 前缀），如 "1.8.0"
  Future<String> getLatestVersion(KernelType type) async {
    try {
      final client = HttpClient();
      final url = Uri.parse(
        'https://api.github.com/repos/${type.repo}/releases/latest',
      );
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tagName = json['tag_name'] as String;
        return tagName.replaceFirst('v', '');
      }
      return '';
    } catch (e) {
      _error = 'Failed to fetch version: $e';
      return '';
    }
  }

  /// 从 GitHub Releases API 获取指定内核的发布列表
  ///
  /// [count] 获取的发布数量，默认20条
  /// 返回包含标签、名称、发布时间、下载资源等信息的列表
  Future<List<KernelReleaseInfo>> getReleaseList(KernelType type, {int count = 20}) async {
    try {
      final client = HttpClient();
      final url = Uri.parse(
        'https://api.github.com/repos/${type.repo}/releases?per_page=$count',
      );
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List;
        return list.map((item) {
          final assets = (item['assets'] as List?) ?? [];
          return KernelReleaseInfo(
            tagName: item['tag_name'] as String,
            name: item['name'] as String? ?? item['tag_name'] as String,
            publishedAt: item['published_at'] as String? ?? '',
            htmlUrl: item['html_url'] as String? ?? '',
            assets: assets.map((a) => KernelAssetInfo(
              name: a['name'] as String,
              url: a['browser_download_url'] as String,
              size: a['size'] as int? ?? 0,
            )).toList(),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      _error = 'Failed to fetch releases: $e';
      return [];
    }
  }

  /// 下载进度，0.0 ~ 1.0，null 表示无法获取总大小
  double? _downloadProgress;

  /// 下载进度（0.0 ~ 1.0）
  double? get downloadProgress => _downloadProgress;

  /// 下载并安装指定内核
  ///
  /// 流程：
  /// 1. 确定版本号（未指定则查询最新版本）
  /// 2. 根据平台和架构构建下载 URL
  /// 3. 下载压缩包到临时文件，实时更新进度
  /// 4. 解压安装（.zip 使用 ZipDecoder，.gz 使用 GZipDecoder）
  /// 5. 设置可执行权限（Linux/macOS）
  /// 6. 更新安装状态和版本信息
  Future<void> downloadKernel(KernelType type, {String? version}) async {
    _statusMap[type] = KernelStatus.downloading;
    _downloadProgress = 0;
    _error = null;
    notifyListeners();

    try {
      version ??= await getLatestVersion(type);
      if (version.isEmpty) {
        throw Exception('Could not determine version for ${type.label}');
      }

      final platform = _getCurrentPlatform();
      final arch = _getCurrentArch();
      final url = KernelInfo.buildDownloadUrl(type, version, platform, arch);

      final dir = await getKernelDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      final ext = url.endsWith('.zip') ? '.zip' : '.gz';
      final archivePath = '${dir.path}/${type.name}_download$ext';
      final file = File(archivePath);
      final sink = file.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress = receivedBytes / totalBytes;
        } else {
          _downloadProgress = null;
        }
        notifyListeners();
      }
      await sink.close();

      _downloadProgress = null;
      _statusMap[type] = KernelStatus.installing;
      notifyListeners();

      await _installKernel(type, archivePath, dir.path);

      _statusMap[type] = KernelStatus.installed;
      _versionMap[type] = version;
      _kernels[type] = KernelInfo(
        type: type,
        version: version,
        binaryPath: '${dir.path}/${getBinaryName(type)}',
      );
      _error = null;
    } catch (e) {
      _downloadProgress = null;
      _statusMap[type] = KernelStatus.error;
      _error = 'Download failed: $e';
    }

    notifyListeners();
  }

  /// 安装内核：解压压缩包并设置权限
  ///
  /// 支持 .zip 和 .gz 两种压缩格式
  /// 安装完成后删除临时压缩包
  /// 非 Windows 平台自动设置 chmod +x 可执行权限
  Future<void> _installKernel(
    KernelType type,
    String archivePath,
    String targetDir,
  ) async {
    final file = File(archivePath);
    final bytes = await file.readAsBytes();

    if (archivePath.endsWith('.zip')) {
      await _extractZip(bytes, targetDir);
    } else if (archivePath.endsWith('.gz')) {
      await _extractGz(bytes, targetDir, type);
    }

    await file.delete();

    final binaryPath = '$targetDir/${getBinaryName(type)}';
    final binaryFile = File(binaryPath);
    if (await binaryFile.exists() && !Platform.isWindows) {
      await Process.run('chmod', ['+x', binaryPath]);
    }
  }

  /// 解压 ZIP 格式压缩包到目标目录
  Future<void> _extractZip(List<int> bytes, String targetDir) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      if (filename.endsWith('/')) {
        await Directory('$targetDir/$filename').create(recursive: true);
      } else {
        final outputFile = File('$targetDir/$filename');
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(file.content);
      }
    }
  }

  /// 解压 GZ 格式压缩包到目标目录
  ///
  /// GZ 文件直接解压为内核二进制文件
  Future<void> _extractGz(
    List<int> bytes,
    String targetDir,
    KernelType type,
  ) async {
    final decompressed = GZipDecoder().decodeBytes(bytes);
    final outputName = getBinaryName(type);
    final outputFile = File('$targetDir/$outputName');
    await outputFile.writeAsBytes(decompressed);
  }

  /// 删除指定内核
  ///
  /// 运行中的内核不允许删除
  /// 删除二进制文件并清除状态信息
  Future<void> deleteKernel(KernelType type) async {
    if (_statusMap[type] == KernelStatus.running) {
      _error = 'Cannot delete running kernel';
      notifyListeners();
      return;
    }

    try {
      final dir = await getKernelDir();
      final binaryName = getBinaryName(type);
      final binaryFile = File('${dir.path}/$binaryName');

      if (await binaryFile.exists()) {
        await binaryFile.delete();
      }

      _statusMap[type] = KernelStatus.notInstalled;
      _kernels.remove(type);
      _versionMap.remove(type);
    } catch (e) {
      _error = 'Delete failed: $e';
    }

    notifyListeners();
  }

  /// 读取本地已安装内核的版本号
  ///
  /// 从 {kernel_name}.version 文件读取版本信息
  Future<String> _readInstalledVersion(KernelType type) async {
    try {
      final dir = await getKernelDir();
      final versionFile = File('${dir.path}/${type.name}.version');
      if (await versionFile.exists()) {
        return await versionFile.readAsString();
      }
    } catch (_) {}
    return 'unknown';
  }

  /// 获取内核文件存储目录
  ///
  /// 默认路径：{应用目录}/assets/bin
  /// 目录不存在时自动创建
  Future<Directory> getKernelDir() async {
    final appDir = Directory.current;
    final kernelDir = Directory('${appDir.path}/assets/bin');
    if (!await kernelDir.exists()) {
      await kernelDir.create(recursive: true);
    }
    return kernelDir;
  }

  /// 获取当前平台标识字符串
  ///
  /// 返回：windows / darwin / linux / android / unknown
  String _getCurrentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// 获取当前 CPU 架构标识
  ///
  /// 检测顺序：
  /// 1. Dart VM 版本字符串中的 arm64/aarch64
  /// 2. Windows PROCESSOR_ARCHITECTURE 环境变量
  /// 3. macOS/Linux uname -m 命令输出
  /// 默认返回 amd64
  String _getCurrentArch() {
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) return 'arm64';
    if (Platform.isWindows) {
      final procArch =
          Platform.environment['PROCESSOR_ARCHITECTURE']?.toUpperCase() ?? '';
      if (procArch.contains('ARM64')) return 'arm64';
    }
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        final result = Process.runSync('uname', ['-m']);
        final arch = result.stdout.toString().trim().toLowerCase();
        if (arch.contains('arm64') || arch.contains('aarch64')) return 'arm64';
      } catch (_) {}
    }
    return 'amd64';
  }
}
