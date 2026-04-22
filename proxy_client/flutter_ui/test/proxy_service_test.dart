import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:proxy_client/services/proxy_service.dart';
import 'package:proxy_client/models/singbox_config.dart';

void main() {
  group('ProxyService Tests', () {
    late ProxyService service;

    setUp(() {
      service = ProxyService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state should be idle', () {
      expect(service.status, ProxyStatus.idle);
      expect(service.isRunning, false);
      expect(service.currentConfig, isNull);
    });

    test('initialize should create default config', () async {
      await service.initialize();
      
      expect(service.status, ProxyStatus.idle);
      expect(service.currentConfig, isNotNull);
      expect(service.currentConfig!.inbounds.length, greaterThan(0));
      expect(service.currentConfig!.outbounds.length, greaterThan(0));
    });

    test('startProxy should change status to running', () async {
      await service.initialize();
      await service.startProxy();
      
      expect(service.status, ProxyStatus.running);
      expect(service.isRunning, true);
      expect(service.errorMessage, isNull);
    });

    test('stopProxy should change status to idle', () async {
      await service.initialize();
      await service.startProxy();
      await service.stopProxy();
      
      expect(service.status, ProxyStatus.idle);
      expect(service.isRunning, false);
    });

    test('toggleTun should update config', () async {
      await service.initialize();
      expect(service.isTunEnabled, false);
      
      await service.toggleTun(true);
      expect(service.isTunEnabled, true);
      
      await service.toggleTun(false);
      expect(service.isTunEnabled, false);
    });

    test('addOutbound should increase outbounds count', () async {
      await service.initialize();
      final initialCount = service.currentConfig!.outbounds.length;
      
      service.addOutbound(Outbound(
        type: 'vmess',
        tag: 'test-node',
        server: 'example.com',
        serverPort: 443,
      ));
      
      expect(service.currentConfig!.outbounds.length, initialCount + 1);
    });

    test('removeOutbound should decrease outbounds count', () async {
      await service.initialize();
      final initialCount = service.currentConfig!.outbounds.length;
      
      // Add then remove
      service.addOutbound(Outbound(
        type: 'trojan',
        tag: 'temp-node',
        server: 'temp.com',
        serverPort: 80,
      ));
      
      expect(service.currentConfig!.outbounds.length, initialCount + 1);
      
      service.removeOutbound('temp-node');
      expect(service.currentConfig!.outbounds.length, initialCount);
    });

    test('exportConfig should return valid JSON', () async {
      await service.initialize();
      final jsonStr = service.exportConfig();
      
      expect(jsonStr, isNotEmpty);
      expect(jsonStr.startsWith('{'), true);
    });

    test('importConfig should parse valid JSON', () async {
      await service.initialize();
      
      final testConfig = {
        'log': {'level': 'debug'},
        'inbounds': [
          {'type': 'mixed', 'tag': 'test-in', 'listen': '127.0.0.1', 'listen_port': 1080}
        ],
        'outbounds': [
          {'type': 'direct', 'tag': 'direct'}
        ],
        'route': {'rules': [], 'geosite': [], 'geoip': []},
        'dns': {'servers': [], 'rules': []},
        'experimental': {},
      };
      
      await service.importConfig('''
        {
          "log": {"level": "debug"},
          "inbounds": [{"type": "mixed", "tag": "test-in", "listen": "127.0.0.1", "listen_port": 1080}],
          "outbounds": [{"type": "direct", "tag": "direct"}],
          "route": {"rules": [], "geosite": [], "geoip": []},
          "dns": {"servers": [], "rules": []},
          "experimental": {}
        }
      ''');
      
      expect(service.currentConfig!.logLevel, 'debug');
      expect(service.currentConfig!.inbounds.first.tag, 'test-in');
    });

    test('switchOutbound should update selected outbound', () async {
      await service.initialize();
      expect(service.selectedOutbound, 'direct');
      
      await service.switchOutbound('proxy');
      expect(service.selectedOutbound, 'proxy');
    });

    test('testLatency should return map of latencies', () async {
      await service.initialize();
      final latencies = await service.testLatency();
      
      expect(latencies, isA<Map<String, double>>());
      expect(latencies.isNotEmpty, true);
    });
  });

  group('SingBoxConfig Model Tests', () {
    test('should serialize and deserialize correctly', () {
      final config = SingBoxConfig(
        logLevel: 'info',
        inbounds: [
          Inbound(type: 'mixed', tag: 'mixed-in', listen: '127.0.0.1', listenPort: 2080),
        ],
        outbounds: [
          Outbound(type: 'direct', tag: 'direct'),
        ],
        route: RouteConfig(
          rules: [],
          geosite: [],
          geoip: [],
        ),
        dns: DnsConfig(
          servers: [
            DnsServer(tag: 'dns-local', address: '8.8.8.8'),
          ],
          rules: [],
        ),
        experimental: ExperimentalConfig(
          tun: TunConfig(enabled: true, stack: 'mixed'),
        ),
      );

      final json = config.toJson();
      final restored = SingBoxConfig.fromJson(json);

      expect(restored.logLevel, config.logLevel);
      expect(restored.inbounds.length, config.inbounds.length);
      expect(restored.outbounds.length, config.outbounds.length);
      expect(restored.experimental.tun?.enabled, true);
    });

    test('Outbound with TLS should serialize correctly', () {
      final outbound = Outbound(
        type: 'vmess',
        tag: 'tls-node',
        server: 'secure.example.com',
        serverPort: 443,
        uuid: 'test-uuid',
        tls: TlsConfig(
          enabled: true,
          serverName: 'secure.example.com',
          insecure: false,
          utls: 'chrome',
        ),
      );

      final json = outbound.toJson();
      expect(json['type'], 'vmess');
      expect(json['tls'], isNotNull);
      expect(json['tls']['enabled'], true);
      expect(json['tls']['server_name'], 'secure.example.com');
    });

    test('RouteConfig with rules should serialize correctly', () {
      final route = RouteConfig(
        autoDetectInterface: true,
        rules: [
          RuleConfig(outbound: 'proxy', domainSuffix: ['.google.com']),
          RuleConfig(outbound: 'direct', ipCidr: ['192.168.0.0/16']),
        ],
        geosite: [
          GeoSiteEntry(tag: 'cn', url: 'https://example.com/geosite-cn.srs'),
        ],
        geoip: [],
      );

      final json = route.toJson();
      expect(json['auto_detect_interface'], true);
      expect(json['rules'].length, 2);
      expect(json['geosite'].length, 1);
    });

    test('DnsConfig with split DNS should serialize correctly', () {
      final dns = DnsConfig(
        servers: [
          DnsServer(tag: 'local', address: '223.5.5.5'),
          DnsServer(tag: 'remote', address: 'tls://8.8.8.8', strategy: 'prefer_ipv4'),
        ],
        rules: [
          DnsRule(server: 'local', domainSuffix: ['.cn']),
          DnsRule(server: 'remote', domainSuffix: ['.google.com']),
        ],
        finalServer: 'local',
      );

      final json = dns.toJson();
      expect(json['servers'].length, 2);
      expect(json['rules'].length, 2);
      expect(json['final'], 'local');
    });
  });

  group('Protocol Support Tests', () {
    test('should support Hysteria2 outbound', () {
      final hysteria = Outbound(
        type: 'hysteria2',
        tag: 'hy2-node',
        server: 'hy2.example.com',
        serverPort: 8443,
        password: 'secret',
        upMbps: '100',
        downMbps: '500',
        tls: TlsConfig(enabled: true, serverName: 'hy2.example.com'),
      );

      final json = hysteria.toJson();
      expect(json['type'], 'hysteria2');
      expect(json['up_mbps'], '100');
      expect(json['down_mbps'], '500');
    });

    test('should support TUIC outbound', () {
      final tuic = Outbound(
        type: 'tuic',
        tag: 'tuic-node',
        server: 'tuic.example.com',
        serverPort: 10443,
        uuid: 'test-uuid',
        password: 'password',
        congestionControl: 'bbr',
        tls: TlsConfig(enabled: true, serverName: 'tuic.example.com'),
      );

      final json = tuic.toJson();
      expect(json['type'], 'tuic');
      expect(json['congestion_control'], 'bbr');
    });

    test('should support VLESS with REALITY', () {
      final vless = Outbound(
        type: 'vless',
        tag: 'reality-node',
        server: 'reality.example.com',
        serverPort: 443,
        uuid: 'test-uuid',
        flow: 'xtls-rprx-vision',
        tls: TlsConfig(enabled: true, serverName: 'reality.example.com', utls: 'chrome'),
        reality: RealityConfig(enabled: true, publicKey: 'abc123', shortId: '12345678'),
      );

      final json = vless.toJson();
      expect(json['type'], 'vless');
      expect(json['reality'], isNotNull);
      expect(json['reality']['enabled'], true);
      expect(json['reality']['public_key'], 'abc123');
    });

    test('should support WireGuard outbound', () {
      final wg = Outbound(
        type: 'wireguard',
        tag: 'wg-node',
        server: 'wg.example.com',
        serverPort: 51820,
      );

      final json = wg.toJson();
      expect(json['type'], 'wireguard');
    });

    test('should support Shadowsocks 2022', () {
      final ss = Outbound(
        type: 'shadowsocks',
        tag: 'ss2022-node',
        server: 'ss.example.com',
        serverPort: 8388,
        password: 'secret-password',
      );

      final json = ss.toJson();
      expect(json['type'], 'shadowsocks');
    });
  });

  group('TUN Mode Tests', () {
    test('TunConfig should have correct defaults', () {
      final tun = TunConfig();
      
      expect(tun.enabled, false);
      expect(tun.stack, 'mixed');
      expect(tun.autoRoute, true);
      expect(tun.strictRoute, false);
    });

    test('TunConfig with Android package filters', () {
      final tun = TunConfig(
        enabled: true,
        includedPackages: ['com.android.chrome', 'org.mozilla.firefox'],
        excludedPackages: ['com.whatsapp'],
      );

      final json = tun.toJson();
      expect(json['included_packages'], isNotNull);
      expect(json['excluded_packages'], isNotNull);
    });
  });
}
