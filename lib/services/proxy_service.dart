import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/singbox_config.dart';
import '../utils/app_exceptions.dart';

enum ProxyStatus { idle, starting, running, stopping, error }

class ProxyService extends ChangeNotifier {
  ProxyStatus _status = ProxyStatus.idle;
  SingBoxConfig? _currentConfig;
  String? _errorMessage;
  int _trafficUp = 0;
  int _trafficDown = 0;
  double _latency = 0;
  String _selectedOutbound = 'direct';
  Timer? _trafficTimer;
  
  // Getters
  ProxyStatus get status => _status;
  SingBoxConfig? get currentConfig => _currentConfig;
  String? get errorMessage => _errorMessage;
  int get trafficUp => _trafficUp;
  int get trafficDown => _trafficDown;
  double get latency => _latency;
  String get selectedOutbound => _selectedOutbound;
  bool get isRunning => _status == ProxyStatus.running;
  bool get isTunEnabled => _currentConfig?.experimental.tun?.enabled ?? false;

  /// Initialize with default configuration
  Future<void> initialize() async {
    _status = ProxyStatus.starting;
    notifyListeners();
    
    try {
      // Load default config or from storage
      _currentConfig = _createDefaultConfig();
      _status = ProxyStatus.idle;
      notifyListeners();
    } catch (e) {
      _status = ProxyStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Create a comprehensive default sing-box config
  SingBoxConfig _createDefaultConfig() {
    return SingBoxConfig(
      logLevel: 'info',
      inbounds: [
        Inbound(
          type: 'mixed',
          tag: 'mixed-in',
          listen: '127.0.0.1',
          listenPort: 2080,
        ),
        Inbound(
          type: 'socks',
          tag: 'socks-in',
          listen: '127.0.0.1',
          listenPort: 2081,
        ),
        Inbound(
          type: 'http',
          tag: 'http-in',
          listen: '127.0.0.1',
          listenPort: 2082,
        ),
      ],
      outbounds: [
        Outbound(
          type: 'direct',
          tag: 'direct',
        ),
        Outbound(
          type: 'block',
          tag: 'block',
        ),
        Outbound(
          type: 'dns',
          tag: 'dns-out',
        ),
        // Selector for manual switching
        Outbound(
          type: 'selector',
          tag: 'proxy',
          // outbounds will be populated dynamically
        ),
        // Auto test for latency-based selection
        Outbound(
          type: 'urltest',
          tag: 'auto',
          // outbounds and url will be populated dynamically
        ),
      ],
      route: RouteConfig(
        autoDetectInterface: true,
        rules: [
          RuleConfig(outbound: 'dns-out', protocol: 'dns'),
          RuleConfig(outbound: 'direct', ipCidr: ['192.168.0.0/16', '10.0.0.0/8']),
          RuleConfig(outbound: 'proxy', domainSuffix: ['.google.com', '.youtube.com']),
        ],
        geosite: [
          GeoSiteEntry(tag: 'geosite-cn', url: 'https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite-cn.srs'),
          GeoSiteEntry(tag: 'geosite-geolocation-!cn', url: 'https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite-geolocation-!cn.srs'),
        ],
        geoip: [
          GeoIpEntry(tag: 'geoip-cn', url: 'https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip-cn.srs'),
        ],
      ),
      dns: DnsConfig(
        servers: [
          DnsServer(tag: 'dns-local', address: '223.5.5.5'),
          DnsServer(tag: 'dns-remote', address: 'tls://8.8.8.8'),
          DnsServer(tag: 'dns-block', address: 'rcode://success'),
        ],
        rules: [
          DnsRule(server: 'dns-local', domainSuffix: ['.cn']),
          DnsRule(server: 'dns-remote', domainSuffix: ['.google.com']),
          DnsRule(server: 'dns-block', type: 'AAAA'),
        ],
        finalServer: 'dns-local',
        client: ClientDns(strategy: 'prefer_ipv4'),
      ),
      experimental: ExperimentalConfig(
        tun: TunConfig(
          enabled: false,
          stack: 'mixed',
          autoRoute: true,
          strictRoute: false,
        ),
        clashApi: ClashApiConfig(
          externalController: true,
          externalUi: 'ui',
          secret: '',
        ),
      ),
    );
  }

  /// Start the proxy core
  Future<void> startProxy() async {
    if (_currentConfig == null) {
      final error = ProxyException('No configuration loaded');
      _errorMessage = error.message;
      _status = ProxyStatus.error;
      notifyListeners();
      throw error;
    }

    _status = ProxyStatus.starting;
    notifyListeners();

    try {
      // Simulate starting the core (in real app, this calls Rust core via IPC)
      await Future.delayed(const Duration(seconds: 2));
      
      _status = ProxyStatus.running;
      _errorMessage = null;
      
      // Start traffic monitoring simulation
      _startTrafficMonitor();
      
      notifyListeners();
    } catch (e) {
      final error = ProxyException('Failed to start proxy', e);
      _status = ProxyStatus.error;
      _errorMessage = error.message;
      notifyListeners();
      throw error;
    }
  }

  /// Stop the proxy core
  Future<void> stopProxy() async {
    _status = ProxyStatus.stopping;
    notifyListeners();

    try {
      // Simulate stopping
      await Future.delayed(const Duration(milliseconds: 500));
      _status = ProxyStatus.idle;
      _trafficUp = 0;
      _trafficDown = 0;
      _latency = 0;
      _trafficTimer?.cancel(); // Cancel timer when stopping
      notifyListeners();
    } catch (e) {
      final error = ProxyException('Failed to stop proxy', e);
      _status = ProxyStatus.error;
      _errorMessage = error.message;
      notifyListeners();
      throw error;
    }
  }

  /// Toggle TUN mode
  Future<void> toggleTun(bool enabled) async {
    if (_currentConfig == null) return;
    
    _currentConfig = SingBoxConfig(
      logLevel: _currentConfig!.logLevel,
      inbounds: _currentConfig!.inbounds,
      outbounds: _currentConfig!.outbounds,
      route: _currentConfig!.route,
      dns: _currentConfig!.dns,
      experimental: ExperimentalConfig(
        tun: TunConfig(
          enabled: enabled,
          stack: _currentConfig!.experimental.tun?.stack ?? 'mixed',
          autoRoute: _currentConfig!.experimental.tun?.autoRoute ?? true,
        ),
        clashApi: _currentConfig!.experimental.clashApi,
      ),
    );
    
    notifyListeners();
    
    // If running, reload config
    if (_status == ProxyStatus.running) {
      await _reloadConfig();
    }
  }

  /// Switch outbound selector
  Future<void> switchOutbound(String tag) async {
    _selectedOutbound = tag;
    notifyListeners();
    // In real app, update the selector outbound in config and reload
  }

  /// Test latency for all outbounds
  Future<Map<String, double>> testLatency() async {
    // Simulate latency testing
    await Future.delayed(const Duration(seconds: 3));
    return {
      'node1': 120.5,
      'node2': 85.2,
      'node3': 210.8,
    };
  }

  /// Import configuration from JSON string
  Future<void> importConfig(String jsonString) async {
    try {
      if (jsonString.trim().isEmpty) {
        throw ConfigException('Configuration JSON is empty');
      }
      
      final jsonMap = jsonDecode(jsonString);
      
      if (jsonMap is! Map<String, dynamic>) {
        throw ConfigException('Invalid configuration format: expected JSON object');
      }
      
      _currentConfig = SingBoxConfig.fromJson(jsonMap);
      notifyListeners();
    } on FormatException catch (e, stackTrace) {
      final error = ConfigException('Invalid JSON format', e, stackTrace);
      _errorMessage = error.message;
      notifyListeners();
      throw error;
    } catch (e, stackTrace) {
      final error = ConfigException('Failed to parse configuration', e, stackTrace);
      _errorMessage = error.message;
      notifyListeners();
      throw error;
    }
  }

  /// Export configuration to JSON string
  String exportConfig() {
    if (_currentConfig == null) return '{}';
    return jsonEncode(_currentConfig!.toJson());
  }

  /// Reload configuration without restart
  Future<void> _reloadConfig() async {
    // Simulate hot reload
    await Future.delayed(const Duration(milliseconds: 800));
    notifyListeners();
  }

  /// Traffic monitoring simulation
  void _startTrafficMonitor() {
    _trafficTimer?.cancel(); // Cancel existing timer if any
    
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status != ProxyStatus.running) {
        timer.cancel();
        return;
      }
      _trafficUp = _trafficUp + (DateTime.now().millisecond % 100);
      _trafficDown = _trafficDown + (DateTime.now().millisecond % 500);
      _latency = 50 + (DateTime.now().millisecond % 100);
      notifyListeners();
    });
  }

  /// Update routing rules
  void updateRoutingRules(List<RuleConfig> rules) {
    if (_currentConfig == null) return;
    
    _currentConfig = SingBoxConfig(
      logLevel: _currentConfig!.logLevel,
      inbounds: _currentConfig!.inbounds,
      outbounds: _currentConfig!.outbounds,
      route: RouteConfig(
        autoDetectInterface: _currentConfig!.route.autoDetectInterface,
        rules: rules,
        geosite: _currentConfig!.route.geosite,
        geoip: _currentConfig!.route.geoip,
      ),
      dns: _currentConfig!.dns,
      experimental: _currentConfig!.experimental,
    );
    notifyListeners();
  }

  /// Add new outbound (node)
  void addOutbound(Outbound outbound) {
    if (_currentConfig == null) return;
    
    final updatedOutbounds = List<Outbound>.from(_currentConfig!.outbounds)..add(outbound);
    
    _currentConfig = SingBoxConfig(
      logLevel: _currentConfig!.logLevel,
      inbounds: _currentConfig!.inbounds,
      outbounds: updatedOutbounds,
      route: _currentConfig!.route,
      dns: _currentConfig!.dns,
      experimental: _currentConfig!.experimental,
    );
    notifyListeners();
  }

  /// Remove outbound by tag
  void removeOutbound(String tag) {
    if (_currentConfig == null) return;
    
    final updatedOutbounds = _currentConfig!.outbounds.where((o) => o.tag != tag).toList();
    
    _currentConfig = SingBoxConfig(
      logLevel: _currentConfig!.logLevel,
      inbounds: _currentConfig!.inbounds,
      outbounds: updatedOutbounds,
      route: _currentConfig!.route,
      dns: _currentConfig!.dns,
      experimental: _currentConfig!.experimental,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _trafficTimer?.cancel();
    super.dispose();
  }
}
