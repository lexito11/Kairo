import 'package:flutter/material.dart';
import 'kairo_colors.dart';
import 'kairo_typography.dart';

abstract final class KairoTheme {
  static ThemeData get dark {
    final textTheme = KairoTypography.textThemeFor(Brightness.dark);
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: KairoTypography.fontFamily,
      typography: KairoTypography.typography,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: KairoColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: KairoColors.primary500,
        surface: KairoColors.darkBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: KairoColors.darkBg,
        foregroundColor: KairoColors.darkText,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: KairoColors.darkText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData get light {
    final textTheme = KairoTypography.textThemeFor(Brightness.light);
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: KairoTypography.fontFamily,
      typography: KairoTypography.typography,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      colorScheme: const ColorScheme.light(
        primary: KairoColors.primary600,
        surface: Color(0xFFF9FAFB),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF9FAFB),
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF111827),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
