import 'dart:io';

/// 平台架构检测工具类
class PlatformDetector {
  /// 获取当前平台标识
  static String getPlatformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// 获取当前系统架构
  static String getArchitecture() {
    try {
      // 尝试使用 uname 命令检测架构（Unix-like 系统）
      if (!Platform.isWindows) {
        final result = Process.runSync('uname', ['-m']);
        if (result.exitCode == 0 && result.stdout != null) {
          final arch = result.stdout.toString().trim().toLowerCase();
          return _parseArchitecture(arch);
        }
      }
      
      // Windows 系统检测
      if (Platform.isWindows) {
        final result = Process.runSync('wmic', ['os', 'get', 'osarchitecture']);
        if (result.exitCode == 0 && result.stdout != null) {
          final arch = result.stdout.toString().trim().toLowerCase();
          if (arch.contains('64-bit') || arch.contains('64 bit')) {
            return 'amd64';
          } else if (arch.contains('32-bit') || arch.contains('32 bit')) {
            return '386';
          }
        }
        // 默认 Windows 为 amd64
        return 'amd64';
      }
      
      // 默认返回 amd64
      return 'amd64';
    } catch (e) {
      // 如果所有检测方法都失败，返回默认架构
      return 'amd64';
    }
  }

  /// 解析架构字符串
  static String _parseArchitecture(String arch) {
    // ARM 架构
    if (arch.contains('arm64') || arch.contains('aarch64')) {
      return 'arm64';
    }
    if (arch.contains('armv6') || arch.contains('armv7') || arch.contains('arm')) {
      return 'arm';
    }
    
    // x86 架构
    if (arch.contains('x86_64') || arch.contains('amd64') || arch.contains('x64')) {
      return 'amd64';
    }
    if (arch.contains('i386') || arch.contains('i686') || arch.contains('x86')) {
      return '386';
    }
    
    // 其他架构
    if (arch.contains('mips64')) {
      return 'mips64';
    }
    if (arch.contains('mips')) {
      return 'mips';
    }
    if (arch.contains('ppc64') || arch.contains('powerpc64')) {
      return 'ppc64';
    }
    if (arch.contains('ppc') || arch.contains('powerpc')) {
      return 'ppc';
    }
    if (arch.contains('s390x')) {
      return 's390x';
    }
    if (arch.contains('riscv64')) {
      return 'riscv64';
    }
    
    // 默认返回 amd64
    return 'amd64';
  }

  /// 获取完整的目标平台标识符（用于下载链接）
  static String getTargetPlatform() {
    final platform = getPlatformName();
    final arch = getArchitecture();
    
    // 特殊处理 Android 平台
    if (platform == 'android') {
      // Android 需要特殊的架构标识
      switch (arch) {
        case 'arm64':
          return 'android-arm64-v8a';
        case 'arm':
          return 'android-armeabi-v7a';
        case '386':
          return 'android-x86';
        case 'amd64':
          return 'android-x86_64';
        default:
          return 'android-arm64-v8a';
      }
    }
    
    return '$platform-$arch';
  }
}