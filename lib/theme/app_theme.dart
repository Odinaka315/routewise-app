import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles. Headings use Manrope, body copy uses DM Sans (as in the design).
class AppText {
  AppText._();

  static TextStyle heading(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w800,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing ?? -size * 0.02,
    );
  }

  static TextStyle body(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: Colors.white,
      secondary: c.accent,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.ink,
      outline: c.line,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: c.canvas,
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme)
          .apply(bodyColor: c.ink, displayColor: c.ink),
      dividerColor: c.line,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: AppText.body(14, c.surface),
      ),
    );
  }
}
