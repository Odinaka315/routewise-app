import 'package:flutter/material.dart';

/// Design tokens ported from the CSS variables in the Figma Make project
/// (`:root` and `.dark`). Use `context.c` to get the palette for the
/// current brightness.
class AppColors {
  const AppColors._({
    required this.isDark,
    required this.ink,
    required this.muted,
    required this.line,
    required this.canvas,
    required this.surface,
    required this.soft,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.blue,
    required this.blueSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
  });

  final bool isDark;
  final Color ink;
  final Color muted;
  final Color line;
  final Color canvas;
  final Color surface;
  final Color soft;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color accent;
  final Color accentSoft;
  final Color blue;
  final Color blueSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warning;

  static const AppColors light = AppColors._(
    isDark: false,
    ink: Color(0xFF17211F),
    muted: Color(0xFF6D7976),
    line: Color(0xFFDFE6E3),
    canvas: Color(0xFFF4F7F5),
    surface: Color(0xFFFFFFFF),
    soft: Color(0xFFEDF2EF),
    primary: Color(0xFF0D684F),
    primaryDark: Color(0xFF084C3B),
    primarySoft: Color(0xFFDFF2E9),
    accent: Color(0xFFF36F4B),
    accentSoft: Color(0xFFFFF0EA),
    blue: Color(0xFF3D77D3),
    blueSoft: Color(0xFFE7EFFC),
    danger: Color(0xFFBD3F3F),
    dangerSoft: Color(0xFFFDECEC),
    warning: Color(0xFF9A6714),
  );

  static const AppColors dark = AppColors._(
    isDark: true,
    ink: Color(0xFFEDF4F1),
    muted: Color(0xFF9DABA7),
    line: Color(0xFF30413C),
    canvas: Color(0xFF111916),
    surface: Color(0xFF19231F),
    soft: Color(0xFF22302B),
    primary: Color(0xFF47C699),
    primaryDark: Color(0xFF70DBB4),
    primarySoft: Color(0xFF173C31),
    accent: Color(0xFFF36F4B),
    accentSoft: Color(0xFF41261F),
    blue: Color(0xFF3D77D3),
    blueSoft: Color(0xFF1C304F),
    danger: Color(0xFFBD3F3F),
    dangerSoft: Color(0xFF432020),
    warning: Color(0xFF9A6714),
  );

  // Colours that do not change with the theme.
  static const Color sidebar = Color(0xFF0E3F32);
  static const Color star = Color(0xFFD79A1E);
  static const Color avatarBg = Color(0xFFF5B59E);
  static const Color avatarFg = Color(0xFF5D2B20);
  static const Color mapBg = Color(0xFFE7ECE5);
  static const Color mapRoad = Color(0xFFC9D2CC);
  static const Color mapWater = Color(0xFFCBDEDC);
  static const Color mapLabel = Color(0xFF8A9892);
  static const Color mint = Color(0xFF8BD6BD);
  static const Color toggleOff = Color(0xFFA9B2AF);
  static const Color placeholder = Color(0xFF99A39F);
  static const Color dragHandle = Color(0xFFA7B0AD);

  List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x121A322B),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  List<BoxShadow> get shadow => [
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x141A322B),
          blurRadius: 34,
          offset: const Offset(0, 12),
        ),
      ];
}

extension AppColorsContext on BuildContext {
  AppColors get c =>
      Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}
