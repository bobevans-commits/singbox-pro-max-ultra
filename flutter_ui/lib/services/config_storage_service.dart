import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Configuration storage service using shared_preferences
class ConfigStorageService extends ChangeNotifier {
  static const String _keySubscriptions = 'subscriptions';
  static const String _keyCurrentConfig = 'current_config';
  static const String _keySettings = 'settings';

  Map<String, dynamic> _storage = {};
  bool _isLoaded = false;

  // Getters
  bool get isLoaded => _isLoaded;

  /// Initialize storage (load from disk)
  Future<void> initialize() async {
    try {
      // In a real app, this would load from shared_preferences or file system
      // For now, we'll use in-memory storage
      _storage = {};
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize storage: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save subscriptions
  Future<void> saveSubscriptions(List<Map<String, dynamic>> subscriptions) async {
    _storage[_keySubscriptions] = jsonEncode(subscriptions);
    notifyListeners();
    // In real app: await SharedPreferences.getInstance().then((prefs) => prefs.setString(_keySubscriptions, jsonEncode(subscriptions)));
  }

  /// Load subscriptions
  List<Map<String, dynamic>>? loadSubscriptions() {
    final data = _storage[_keySubscriptions];
    if (data == null) return null;
    
    try {
      final list = jsonDecode(data) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Save current configuration
  Future<void> saveCurrentConfig(Map<String, dynamic> config) async {
    _storage[_keyCurrentConfig] = jsonEncode(config);
    notifyListeners();
  }

  /// Load current configuration
  Map<String, dynamic>? loadCurrentConfig() {
    final data = _storage[_keyCurrentConfig];
    if (data == null) return null;
    
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Save settings
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    _storage[_keySettings] = jsonEncode(settings);
    notifyListeners();
  }

  /// Load settings
  Map<String, dynamic>? loadSettings() {
    final data = _storage[_keySettings];
    if (data == null) return null;
    
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    _storage.clear();
    notifyListeners();
  }

  /// Export all data to JSON string
  String exportAll() {
    return jsonEncode(_storage);
  }

  /// Import data from JSON string
  Future<void> importAll(String jsonString) async {
    try {
      _storage = jsonDecode(jsonString) as Map<String, dynamic>;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }
}

/// App settings model
class AppSettings {
  final bool autoStart;
  final bool startOnBoot;
  final bool minimizeToTray;
  final bool darkMode;
  final String language;
  final int defaultPort;
  final bool enableTunByDefault;
  final String logLevel;

  AppSettings({
    this.autoStart = false,
    this.startOnBoot = false,
    this.minimizeToTray = true,
    this.darkMode = false,
    this.language = 'en',
    this.defaultPort = 2080,
    this.enableTunByDefault = false,
    this.logLevel = 'info',
  });

  Map<String, dynamic> toJson() => {
        'autoStart': autoStart,
        'startOnBoot': startOnBoot,
        'minimizeToTray': minimizeToTray,
        'darkMode': darkMode,
        'language': language,
        'defaultPort': defaultPort,
        'enableTunByDefault': enableTunByDefault,
        'logLevel': logLevel,
      };

  static AppSettings fromJson(Map<String, dynamic> json) {
    return AppSettings(
      autoStart: json['autoStart'] ?? false,
      startOnBoot: json['startOnBoot'] ?? false,
      minimizeToTray: json['minimizeToTray'] ?? true,
      darkMode: json['darkMode'] ?? false,
      language: json['language'] ?? 'en',
      defaultPort: json['defaultPort'] ?? 2080,
      enableTunByDefault: json['enableTunByDefault'] ?? false,
      logLevel: json['logLevel'] ?? 'info',
    );
  }

  AppSettings copyWith({
    bool? autoStart,
    bool? startOnBoot,
    bool? minimizeToTray,
    bool? darkMode,
    String? language,
    int? defaultPort,
    bool? enableTunByDefault,
    String? logLevel,
  }) {
    return AppSettings(
      autoStart: autoStart ?? this.autoStart,
      startOnBoot: startOnBoot ?? this.startOnBoot,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      defaultPort: defaultPort ?? this.defaultPort,
      enableTunByDefault: enableTunByDefault ?? this.enableTunByDefault,
      logLevel: logLevel ?? this.logLevel,
    );
  }
}
