import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/config.dart';
import '../models/kernel_info.dart';

class KernelManager extends ChangeNotifier {
  final Map<KernelType, KernelInfo> _kernels = {};
  final Map<KernelType, KernelStatus> _statusMap = {};
  final Map<KernelType, String> _versionMap = {};
  String? _error;

  Map<KernelType, KernelInfo> get kernels => Map.unmodifiable(_kernels);
  Map<KernelType, KernelStatus> get statusMap => Map.unmodifiable(_statusMap);
  String? get error => _error;

  KernelStatus getStatus(KernelType type) =>
      _statusMap[type] ?? KernelStatus.notInstalled;

  String? getVersion(KernelType type) => _versionMap[type];

  bool isInstalled(KernelType type) {
    final status = _statusMap[type];
    return status == KernelStatus.installed || status == KernelStatus.running;
  }

  Future<void> init() async {
    for (final type in KernelType.values) {
      _statusMap[type] = KernelStatus.notInstalled;
      await _checkInstalled(type);
    }
    notifyListeners();
  }

  Future<void> _checkInstalled(KernelType type) async {
    try {
      final dir = await _getKernelDir();
      final binaryName = _getBinaryName(type);
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
        final version = tagName.replaceFirst('v', '');
        return version;
      }
      return '';
    } catch (e) {
      _error = 'Failed to fetch version: $e';
      return '';
    }
  }

  Future<void> downloadKernel(KernelType type, {String? version}) async {
    _statusMap[type] = KernelStatus.downloading;
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

      final dir = await _getKernelDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final archivePath = '${dir.path}/${type.name}_download';
      final file = File(archivePath);
      await response.pipe(file.openWrite());

      _statusMap[type] = KernelStatus.installing;
      notifyListeners();

      await _installKernel(type, archivePath, dir.path);

      _statusMap[type] = KernelStatus.installed;
      _versionMap[type] = version;
      _kernels[type] = KernelInfo(
        type: type,
        version: version,
        binaryPath: '${dir.path}/${_getBinaryName(type)}',
      );
      _error = null;
    } catch (e) {
      _statusMap[type] = KernelStatus.error;
      _error = 'Download failed: $e';
    }

    notifyListeners();
  }

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

    final binaryPath = '$targetDir/${_getBinaryName(type)}';
    final binaryFile = File(binaryPath);
    if (await binaryFile.exists() && !Platform.isWindows) {
      await Process.run('chmod', ['+x', binaryPath]);
    }
  }

  Future<void> _extractZip(List<int> bytes, String targetDir) async {
    final archive = Archive();
    final zipData = ZipDecoder().decodeBytes(bytes);
    for (final file in zipData) {
      final path = '$targetDir/${file.name}';
      if (file.isFile) {
        await File(path).writeAsBytes(file.content);
      } else {
        await Directory(path).create(recursive: true);
      }
    }
  }

  Future<void> _extractGz(
    List<int> bytes,
    String targetDir,
    KernelType type,
  ) async {
    final outputName = _getBinaryName(type);
    final outputFile = File('$targetDir/$outputName');
    await outputFile.writeAsBytes(bytes);
  }

  Future<void> deleteKernel(KernelType type) async {
    if (_statusMap[type] == KernelStatus.running) {
      _error = 'Cannot delete running kernel';
      notifyListeners();
      return;
    }

    try {
      final dir = await _getKernelDir();
      final binaryName = _getBinaryName(type);
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

  String _getBinaryName(KernelType type) {
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

  Future<String> _readInstalledVersion(KernelType type) async {
    try {
      final dir = await _getKernelDir();
      final versionFile = File('${dir.path}/${type.name}.version');
      if (await versionFile.exists()) {
        return await versionFile.readAsString();
      }
    } catch (_) {}
    return 'unknown';
  }

  Future<Directory> _getKernelDir() async {
    final appDir = Directory.current;
    final kernelDir = Directory('${appDir.path}/assets/bin');
    if (!await kernelDir.exists()) {
      await kernelDir.create(recursive: true);
    }
    return kernelDir;
  }

  String _getCurrentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  String _getCurrentArch() {
    return 'amd64';
  }
}

class Archive {
  List<ArchiveFile> decodeBytes(List<int> bytes) => [];
}

class ZipDecoder {
  List<ArchiveFile> decodeBytes(List<int> bytes) => [];
}

class ArchiveFile {
  final String name;
  final bool isFile;
  final List<int> content;
  ArchiveFile(this.name, this.isFile, this.content);
}
