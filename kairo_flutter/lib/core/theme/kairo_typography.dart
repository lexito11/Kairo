import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tipografía nativa por plataforma:
/// - iOS / macOS → San Francisco (sistema Cupertino)
/// - Android / web / resto → Roboto
abstract final class KairoTypography {
  /// Factor de tamaño global (la UI estaba muy pequeña).
  static const double textScaleFactor = 1.12;

  static TargetPlatform get _platform {
    if (kIsWeb) return TargetPlatform.android;
    return defaultTargetPlatform;
  }

  static Typography get typography =>
      Typography.material2021(platform: _platform);

  /// null en Apple = San Francisco del sistema; Roboto en el resto.
  static String? get fontFamily {
    switch (_platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return null;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 'Roboto';
    }
  }

  static TextTheme textThemeFor(Brightness brightness) {
    // No usar TextTheme.apply(fontSizeFactor: …): falla si algún estilo
    // trae fontSize null. La familia va en ThemeData.fontFamily.
    return brightness == Brightness.dark ? typography.white : typography.black;
  }
}
