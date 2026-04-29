import 'dart:io';

import 'package:flutter/foundation.dart';

class AdminService {
  AdminService._();

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
