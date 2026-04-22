/// Supported kernel types
enum KernelType {
  singBox,
  v2Ray,
  mihomo, // Clash core
}

extension KernelTypeExtension on KernelType {
  String get name {
    switch (this) {
      case KernelType.singBox:
        return 'sing-box';
      case KernelType.v2Ray:
        return 'v2ray';
      case KernelType.mihomo:
        return 'mihomo';
    }
  }

  String get binaryName {
    switch (this) {
      case KernelType.singBox:
        return 'sing-box';
      case KernelType.v2Ray:
        return 'v2ray';
      case KernelType.mihomo:
        return 'clash';
    }
  }

  String get configFileName {
    switch (this) {
      case KernelType.singBox:
        return 'config.json';
      case KernelType.v2Ray:
        return 'config.json';
      case KernelType.mihomo:
        return 'config.yaml';
    }
  }
}

/// Configuration for a kernel
class KernelConfig {
  final KernelType type;
  final String configPath;
  final int apiPort;
  final String? logLevel;
  final Map<String, dynamic>? extraConfig;

  KernelConfig({
    required this.type,
    required this.configPath,
    this.apiPort = 9090,
    this.logLevel,
    this.extraConfig,
  });

  KernelConfig copyWith({
    KernelType? type,
    String? configPath,
    int? apiPort,
    String? logLevel,
    Map<String, dynamic>? extraConfig,
  }) {
    return KernelConfig(
      type: type ?? this.type,
      configPath: configPath ?? this.configPath,
      apiPort: apiPort ?? this.apiPort,
      logLevel: logLevel ?? this.logLevel,
      extraConfig: extraConfig ?? this.extraConfig,
    );
  }
}
