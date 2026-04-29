import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../services/proxy_service.dart';

class TrayService with TrayListener {
  final ProxyService _proxyService;
  bool _initialized = false;

  TrayService(this._proxyService);

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    try {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/icons/tray_icon.ico'
            : 'assets/icons/tray_icon.png',
      );
    } catch (e) {
      debugPrint('[TrayService] Icon not found, using system default: $e');
    }

    _buildMenu();
    trayManager.addListener(this);
    _initialized = true;
  }

  void _buildMenu() {
    final isRunning = _proxyService.isRunning;
    final config = _proxyService.config;

    final menu = Menu(
      items: [
        MenuItem(
          key: 'status',
          label: isRunning ? '● 代理运行中' : '○ 代理未运行',
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem.submenu(
          key: 'proxy_mode',
          label: '代理模式',
          submenu: Menu(
            items: [
              MenuItem(
                key: 'mode_rule',
                label: '${config.tunEnabled ? "  " : "✓ "}规则模式',
              ),
              MenuItem(
                key: 'mode_global',
                label:
                    '${config.tunEnabled && config.lanSharing ? "✓ " : "  "}全局模式',
              ),
              MenuItem(key: 'mode_direct', label: '  直连模式'),
            ],
          ),
        ),
        MenuItem(key: 'toggle', label: isRunning ? '停止代理' : '启动代理'),
        MenuItem.separator(),
        MenuItem(key: 'show', label: '显示主窗口'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: '退出'),
      ],
    );

    trayManager.setContextMenu(menu);
    trayManager.setToolTip(isRunning ? 'ProxCore - 运行中' : 'ProxCore - 未运行');
  }

  void update() {
    if (_initialized) _buildMenu();
  }

  @override
  void onTrayIconMouseDown() {
    _buildMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    _buildMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle':
        if (_proxyService.isRunning) {
          _proxyService.stop();
        } else if (_proxyService.nodes.isNotEmpty) {
          _proxyService.start(_proxyService.nodes.first);
        }
        break;
      case 'mode_rule':
        _proxyService.updateConfig(
          _proxyService.config.copyWith(tunEnabled: false),
        );
        break;
      case 'mode_global':
        _proxyService.toggleTun(true);
        break;
      case 'mode_direct':
        if (_proxyService.isRunning) {
          _proxyService.stop();
        }
        break;
      case 'show':
        break;
      case 'exit':
        exit(0);
    }
    _buildMenu();
  }

  Future<void> destroy() async {
    if (_initialized) {
      trayManager.removeListener(this);
      await trayManager.destroy();
    }
  }
}
