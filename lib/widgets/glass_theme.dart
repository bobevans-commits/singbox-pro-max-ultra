// 毛玻璃主题组件库
// 提供 Glassmorphism（玻璃拟态）风格的 UI 组件
// 包括主题配置、毛玻璃卡片、毛玻璃按钮、毛玻璃开关

import 'dart:ui';

import 'package:flutter/material.dart';

/// 毛玻璃主题配置
///
/// 定义亮色/暗色两套主题，使用 Material 3 规范
/// 主色调：#6C5CE7（紫色），强调色：#00CEFF（青色）
class GlassTheme {
  /// 主色调 — 紫色
  static const Color primaryColor = Color(0xFF6C5CE7);

  /// 强调色 — 青色
  static const Color accentColor = Color(0xFF00CEFF);

  /// 成功色 — 绿色
  static const Color successColor = Color(0xFF00E676);

  /// 警告色 — 琥珀色
  static const Color warningColor = Color(0xFFFFB300);

  /// 错误色 — 红色
  static const Color errorColor = Color(0xFFFF5252);

  /// 亮色主题
  ///
  /// 背景色：#F0F2F5（浅灰）
  /// 卡片：无阴影，16px 圆角
  /// AppBar/NavigationBar：透明背景
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: primaryColor,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: primaryColor.withValues(alpha: 0.15),
        ),
      );

  /// 暗色主题
  ///
  /// 背景色：#0A0E27（深蓝黑）
  /// 卡片：5% 白色透明度，16px 圆角
  /// AppBar/NavigationBar：透明背景
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: primaryColor,
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: primaryColor.withValues(alpha: 0.2),
        ),
      );
}

/// 毛玻璃风格卡片组件
///
/// 使用 BackdropFilter 实现背景模糊效果
/// 支持自定义模糊程度、透明度、圆角、边框、内边距、外边距
///
/// 用法：
/// ```dart
/// GlassCard(
///   blur: 16,
///   opacity: 0.1,
///   child: Text('毛玻璃卡片'),
/// )
/// ```
class GlassCard extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 模糊强度（sigma），默认12
  final double blur;

  /// 背景透明度，默认0.08
  final double opacity;

  /// 圆角半径，默认16
  final double borderRadius;

  /// 内边距，默认16
  final EdgeInsetsGeometry? padding;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 自定义背景色，覆盖默认透明度计算
  final Color? tintColor;

  /// 自定义边框
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 12,
    this.opacity = 0.08,
    this.borderRadius = 16,
    this.padding,
    this.margin,
    this.tintColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = tintColor ??
        (isDark ? Colors.white.withValues(alpha: opacity) : Colors.white.withValues(alpha: opacity + 0.6));

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 毛玻璃风格按钮组件
///
/// 使用 BackdropFilter 实现背景模糊效果
/// 包含 InkWell 水波纹点击效果
class GlassButton extends StatelessWidget {
  /// 子组件（通常为 Text 或 Icon）
  final Widget child;

  /// 点击回调
  final VoidCallback? onPressed;

  /// 自定义背景色
  final Color? color;

  /// 圆角半径，默认12
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = color ?? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.7));

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 毛玻璃风格开关组件
///
/// 自定义动画开关，支持亮色/暗色主题自适应
/// 开启时显示主色调，关闭时显示灰色/暗色
class GlassSwitch extends StatelessWidget {
  /// 当前开关状态
  final bool value;

  /// 状态变化回调
  final ValueChanged<bool> onChanged;

  /// 开启时的颜色，默认使用主色调
  final Color? activeColor;

  const GlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = activeColor ?? GlassTheme.primaryColor;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? color
              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
