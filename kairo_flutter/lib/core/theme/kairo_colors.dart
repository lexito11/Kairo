import 'package:flutter/material.dart';

/// Colores 1:1 con tailwind.config.ts de la web KAIRO
abstract final class KairoColors {
  // primary
  static const primary500 = Color(0xFF0EA5E9);
  static const primary400 = Color(0xFF38BDF8);
  static const primary300 = Color(0xFF7DD3FC);
  static const primary600 = Color(0xFF0284C7);
  static const primary700 = Color(0xFF0369A1);

  // purple (Tailwind default purple-500 / purple-600)
  static const purple500 = Color(0xFFA855F7);
  static const purple600 = Color(0xFF9333EA);

  // dark
  static const darkBg = Color(0xFF0A0A0A);
  static const darkCard = Color(0xFF1A1A1A);
  static const darkHover = Color(0xFF252525);
  static const darkBorder = Color(0xFF2A2A2A);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFA0A0A0);

  // alertas
  static const errorBg = Color(0x33EF4444);
  static const errorBorder = Color(0x80EF4444);
  static const errorText = Color(0xFFF87171);

  static const successBg = Color(0x3322C55E);
  static const successBorder = Color(0x8022C55E);
  static const successText = Color(0xFF4ADE80);

  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary500, purple600],
  );

  static const brandTextGradient = LinearGradient(
    colors: [primary500, purple500],
  );

  static const buttonGradient = LinearGradient(
    colors: [primary500, purple600],
  );
}
