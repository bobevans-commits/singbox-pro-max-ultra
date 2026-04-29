// 管理员权限服务
// 负责请求和检测管理员权限
// TUN 模式需要管理员权限才能创建虚拟网卡

import 'dart:io';

import 'package:flutter/foundation.dart';

/// 管理员权限服务 — 请求和检测系统管理员权限
///
/// 职责：
/// - Windows：通过 UAC 提升权限（PowerShell Start-Process -Verb RunAs）
/// - macOS：通过 osascript 请求管理员权限
/// - 检测当前是否已拥有管理员权限
/// - Linux 默认返回 true（需用户自行 sudo）
class AdminService {
  AdminService._();

  /// 请求管理员权限
  ///
  /// Windows：检测当前权限，不足时通过 UAC 重新启动应用
  /// macOS：通过 osascript 弹出系统授权对话框
  /// Linux：直接返回 true
  static Future<bool> requestAdminPrivileges() async {
    if (!Platform.isWindows && !Platform.isMacOS) return true;

    try {
      if (Platform.isWindows) {
        return await _requestWindowsAdmin();
      } else if (Platform.isMacOS) {
        return await _requestMacAdmin();
      }
    } catch (e) {
      debugPrint('[AdminService] Request admin failed: $e');
      return false;
    }
    return false;
  }

  /// Windows：请求管理员权限
  ///
  /// 1. 先通过 net session 检测是否已有管理员权限
  /// 2. 权限不足时通过 PowerShell UAC 重新启动应用
  /// 3. UAC 启动成功后退出当前进程
  static Future<bool> _requestWindowsAdmin() async {
    try {
      final result = await Process.run('net', ['session']);
      if (result.exitCode == 0) return true;
    } catch (_) {}

    try {
      final exePath = Platform.resolvedExecutable;
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Start-Process',
          '-FilePath',
          '"$exePath"',
          '-Verb',
          'RunAs',
        ],
      );
      if (result.exitCode == 0) {
        exit(0);
      }
    } catch (_) {}

    return false;
  }

  /// macOS：请求管理员权限
  ///
  /// 通过 osascript 执行需要管理员权限的命令
  /// 系统会弹出授权对话框
  static Future<bool> _requestMacAdmin() async {
    try {
      final result = await Process.run('osascript', [
        '-e',
        'do shell script "echo admin_check" with administrator privileges',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 检测当前是否拥有管理员权限
  ///
  /// Windows：通过 net session 命令检测
  /// macOS：通过 id 命令检测是否为 root
  /// Linux：默认返回 true
  static Future<bool> hasAdminPrivileges() async {
    if (!Platform.isWindows && !Platform.isMacOS) return true;

    try {
      if (Platform.isWindows) {
        final result = await Process.run('net', ['session']);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        final result = await Process.run('id', []);
        return (result.stdout as String).contains('root');
      }
    } catch (_) {}

    return false;
  }
}
