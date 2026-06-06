import 'package:flutter/material.dart';
import 'kairo_colors.dart';

abstract final class KairoTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: KairoColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: KairoColors.primary500,
          surface: KairoColors.darkBg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: KairoColors.darkBg,
          foregroundColor: KairoColors.darkText,
          elevation: 0,
        ),
        useMaterial3: true,
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        colorScheme: const ColorScheme.light(
          primary: KairoColors.primary600,
          surface: Color(0xFFF9FAFB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9FAFB),
          foregroundColor: Color(0xFF111827),
          elevation: 0,
        ),
        useMaterial3: true,
      );
}
