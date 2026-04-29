// 系统托盘服务
// 管理系统通知栏图标和右键菜单
// 支持代理启停、模式切换、显示主窗口、退出等操作

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../services/proxy_service.dart';

/// 系统托盘服务 — 管理通知栏图标和右键菜单
///
/// 职责：
/// - 设置托盘图标（Windows: .ico / macOS/Linux: .png）
/// - 构建右键菜单（代理状态、模式切换、启停、退出）
/// - 处理菜单点击事件
/// - 代理状态变化时自动更新菜单
/// - 退出时清理系统代理和托盘资源
class TrayService with TrayListener {
  /// 代理服务实例，用于控制代理启停和获取状态
  final ProxyService _proxyService;

  /// 托盘是否已初始化
  bool _initialized = false;

  TrayService(this._proxyService);

  /// 初始化系统托盘
  ///
  /// 设置图标、构建菜单、注册监听器
  /// 仅在 Windows / Linux / macOS 桌面平台执行
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

  /// 构建右键菜单
  ///
  /// 菜单项：
  /// - 代理运行状态（禁用项，仅显示）
  /// - 代理模式子菜单（规则/全局/直连）
  /// - 启动/停止代理
  /// - 显示主窗口
  /// - 退出
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

  /// 更新托盘菜单（代理状态变化时调用）
  void update() {
    if (_initialized) _buildMenu();
  }

  /// 托盘图标左键点击回调
  @override
  void onTrayIconMouseDown() {
    _buildMenu();
  }

  /// 托盘图标右键点击回调
  @override
  void onTrayIconRightMouseDown() {
    _buildMenu();
  }

  /// 托盘菜单项点击回调
  ///
  /// 处理逻辑：
  /// - toggle：启动/停止代理
  /// - mode_rule：切换到规则模式（关闭 TUN）
  /// - mode_global：切换到全局模式（开启 TUN）
  /// - mode_direct：直连模式（停止代理）
  /// - show：显示主窗口
  /// - exit：停止代理 → 销毁托盘 → 退出进程
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
        _proxyService.stop().then((_) {
          destroy().then((_) => exit(0));
        });
    }
    _buildMenu();
  }

  /// 销毁托盘服务
  ///
  /// 移除监听器并销毁托盘图标
  Future<void> destroy() async {
    if (_initialized) {
      trayManager.removeListener(this);
      await trayManager.destroy();
    }
  }
}
