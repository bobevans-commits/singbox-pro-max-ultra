import 'dart:io';

class SystemProxyService {
  SystemProxyService._();

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

  static Future<void> disable() async {
    if (Platform.isWindows) {
      await _disableWindowsProxy();
    } else if (Platform.isLinux) {
      await _disableLinuxProxy();
    } else if (Platform.isMacOS) {
      await _disableMacProxy();
    }
  }

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

  static Future<void> _disableLinuxProxy() async {
    final file = File('${Directory.current.path}/proxy_env.sh');
    if (await file.exists()) {
      await file.delete();
    }
  }

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
