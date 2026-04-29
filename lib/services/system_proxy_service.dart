// 系统代理服务
// 负责在操作系统层面设置/移除 HTTP/SOCKS 代理
// 支持 Windows（注册表）、macOS（networksetup）、Linux（环境变量脚本）

import 'dart:io';

/// 系统代理服务 — 跨平台系统代理配置
///
/// 职责：
/// - Windows：通过 reg 命令修改注册表 Internet Settings
/// - macOS：通过 networksetup 命令配置网络服务代理
/// - Linux：生成 proxy_env.sh 环境变量脚本
/// - 自动配置代理绕过列表（localhost、私有网络地址）
class SystemProxyService {
  SystemProxyService._();

  /// 启用系统代理
  ///
  /// [host] 代理监听地址，如 127.0.0.1
  /// [httpPort] HTTP 代理端口
  /// [socksPort] SOCKS 代理端口（可选，macOS 使用）
  static Future<void> enable({
    required String host,
    required int httpPort,
    int? socksPort,
  }) async {
    if (Platform.isWindows) {
      await _enableWindowsProxy(host, httpPort);
    } else if (Platform.isLinux) {
      await _enableLinuxProxy(host, httpPort);
    } else if (Platform.isMacOS) {
      await _enableMacProxy(host, httpPort);
    }
  }

  /// 禁用系统代理
  static Future<void> disable() async {
    if (Platform.isWindows) {
      await _disableWindowsProxy();
    } else if (Platform.isLinux) {
      await _disableLinuxProxy();
    } else if (Platform.isMacOS) {
      await _disableMacProxy();
    }
  }

  /// Windows：启用系统代理
  ///
  /// 通过 reg add 命令修改注册表：
  /// - ProxyEnable = 1（启用代理）
  /// - ProxyServer = host:port（代理服务器地址）
  /// - ProxyOverride = 绕过列表（localhost、私有网络）
  static Future<void> _enableWindowsProxy(String host, int port) async {
    final proxyServer = '$host:$port';
    await Process.run('reg', [
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v', 'ProxyEnable',
      '/t', 'REG_DWORD',
      '/d', '1',
      '/f',
    ]);
    await Process.run('reg', [
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v', 'ProxyServer',
      '/t', 'REG_SZ',
      '/d', proxyServer,
      '/f',
    ]);
    await Process.run('reg', [
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v', 'ProxyOverride',
      '/t', 'REG_SZ',
      '/d', 'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*',
      '/f',
    ]);
  }

  /// Windows：禁用系统代理
  ///
  /// 将 ProxyEnable 设置为 0
  static Future<void> _disableWindowsProxy() async {
    await Process.run('reg', [
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v', 'ProxyEnable',
      '/t', 'REG_DWORD',
      '/d', '0',
      '/f',
    ]);
  }

  /// Linux：启用系统代理
  ///
  /// 生成 proxy_env.sh 脚本，设置 http_proxy / https_proxy / ftp_proxy 环境变量
  /// 用户需手动 source 该脚本或配置 shell 自动加载
  static Future<void> _enableLinuxProxy(String host, int port) async {
    final envContent = '''
export http_proxy="http://$host:$port"
export https_proxy="http://$host:$port"
export ftp_proxy="http://$host:$port"
export no_proxy="localhost,127.0.0.1,10.*,172.16.*,172.17.*,172.18.*,172.19.*,172.20.*,172.21.*,172.22.*,172.23.*,172.24.*,172.25.*,172.26.*,172.27.*,172.28.*,172.29.*,172.30.*,172.31.*,192.168.*"
''';
    final file = File('${Directory.current.path}/proxy_env.sh');
    await file.writeAsString(envContent);
  }

  /// Linux：禁用系统代理
  ///
  /// 删除 proxy_env.sh 脚本
  static Future<void> _disableLinuxProxy() async {
    final file = File('${Directory.current.path}/proxy_env.sh');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// macOS：启用系统代理
  ///
  /// 通过 networksetup 命令为所有网络服务设置：
  /// - Web 代理（HTTP）
  /// - 安全 Web 代理（HTTPS）
  /// - SOCKS 防火墙代理
  /// - 代理绕过域名
  static Future<void> _enableMacProxy(String host, int port) async {
    final services = await _getMacNetworkServices();
    for (final service in services) {
      await Process.run('networksetup', [
        '-setwebproxy', service, host, '$port',
      ]);
      await Process.run('networksetup', [
        '-setsecurewebproxy', service, host, '$port',
      ]);
      await Process.run('networksetup', [
        '-setsocksfirewallproxy', service, host, '$port',
      ]);
      await Process.run('networksetup', [
        '-setproxybypassdomains', service,
        'localhost', '127.0.0.1', '*.local', '10.*', '172.16.*', '192.168.*',
      ]);
    }
  }

  /// macOS：禁用系统代理
  ///
  /// 关闭所有网络服务的 Web/HTTPS/SOCKS 代理
  static Future<void> _disableMacProxy() async {
    final services = await _getMacNetworkServices();
    for (final service in services) {
      await Process.run('networksetup', [
        '-setwebproxystate', service, 'off',
      ]);
      await Process.run('networksetup', [
        '-setsecurewebproxystate', service, 'off',
      ]);
      await Process.run('networksetup', [
        '-setsocksfirewallproxystate', service, 'off',
      ]);
    }
  }

  /// 获取 macOS 所有网络服务名称
  ///
  /// 通过 networksetup -listallnetworkservices 获取
  /// 跳过第一行标题和带 * 标记的禁用服务
  static Future<List<String>> _getMacNetworkServices() async {
    try {
      final result = await Process.run(
        'networksetup', ['-listallnetworkservices'],
      );
      final lines = (result.stdout as String).split('\n');
      return lines
          .skip(1)
          .where((l) => l.trim().isNotEmpty && !l.contains('*'))
          .map((l) => l.trim())
          .toList();
    } catch (_) {
      return [];
    }
  }
}
