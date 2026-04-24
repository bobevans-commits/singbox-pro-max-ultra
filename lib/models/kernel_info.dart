import 'config.dart';

class KernelInfo {
  final KernelType type;
  final String version;
  final String binaryPath;
  final String downloadUrl;
  final String platform;
  final String arch;
  final int fileSize;
  final String sha256;

  const KernelInfo({
    required this.type,
    this.version = '',
    this.binaryPath = '',
    this.downloadUrl = '',
    this.platform = '',
    this.arch = '',
    this.fileSize = 0,
    this.sha256 = '',
  });

  KernelInfo copyWith({
    KernelType? type,
    String? version,
    String? binaryPath,
    String? downloadUrl,
    String? platform,
    String? arch,
    int? fileSize,
    String? sha256,
  }) {
    return KernelInfo(
      type: type ?? this.type,
      version: version ?? this.version,
      binaryPath: binaryPath ?? this.binaryPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      platform: platform ?? this.platform,
      arch: arch ?? this.arch,
      fileSize: fileSize ?? this.fileSize,
      sha256: sha256 ?? this.sha256,
    );
  }

  String get fileName {
    final ext = platform == 'windows' ? '.exe' : '';
    switch (type) {
      case KernelType.singbox:
        return 'sing-box$ext';
      case KernelType.mihomo:
        return 'mihomo$ext';
      case KernelType.v2ray:
        return 'xray$ext';
    }
  }

  String get displayName {
    switch (type) {
      case KernelType.singbox:
        return 'sing-box';
      case KernelType.mihomo:
        return 'Mihomo (Clash Meta)';
      case KernelType.v2ray:
        return 'Xray (v2ray)';
    }
  }

  static String getPlatform() {
    final os = const String.fromEnvironment('dart.io.platform');
    if (os.contains('windows')) return 'windows';
    if (os.contains('macos')) return 'darwin';
    if (os.contains('linux')) return 'linux';
    if (os.contains('android')) return 'android';
    return 'unknown';
  }

  static String getArch() {
    const envArch = String.fromEnvironment('dart.io.arch');
    if (envArch.contains('arm64') || envArch.contains('aarch64')) return 'arm64';
    return 'amd64';
  }

  static String buildDownloadUrl(KernelType type, String version, String platform, String arch) {
    switch (type) {
      case KernelType.singbox:
        final archName = platform == 'windows' && arch == 'amd64' ? 'amd64' : arch;
        return 'https://github.com/SagerNet/sing-box/releases/download/v$version/'
            'sing-box-$version-$platform-$archName.zip';
      case KernelType.mihomo:
        final archName = arch == 'amd64' ? 'amd64' : (arch == 'arm64' ? 'arm64' : 'amd64');
        return 'https://github.com/MetaCubeX/mihomo/releases/download/v$version/'
            'mihomo-$platform-$archName-v$version.gz';
      case KernelType.v2ray:
        final archName = platform == 'windows' && arch == 'amd64' ? '64' : arch;
        return 'https://github.com/XTLS/Xray-core/releases/download/v$version/'
            'Xray-$platform-$archName.zip';
    }
  }
}

class KernelReleaseInfo {
  final String tagName;
  final String name;
  final String publishedAt;
  final String htmlUrl;
  final List<KernelAssetInfo> assets;

  const KernelReleaseInfo({
    required this.tagName,
    required this.name,
    required this.publishedAt,
    required this.htmlUrl,
    this.assets = const [],
  });

  String get version => tagName.replaceFirst('v', '');
}

class KernelAssetInfo {
  final String name;
  final String url;
  final int size;

  const KernelAssetInfo({
    required this.name,
    required this.url,
    required this.size,
  });
}
