import 'package:flutter/material.dart';
import '../services/prefs_service.dart';
import '../theme/kairo_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _load();
  }

  final _prefs = PrefsService();
  bool _isDark = true;

  bool get isDark => _isDark;
  ThemeData get theme => _isDark ? KairoTheme.dark : KairoTheme.light;

  Future<void> _load() async {
    final saved = await _prefs.getTheme();
    _isDark = saved != 'light';
    notifyListeners();
  }

  Future<void> toggle(bool dark) async {
    _isDark = dark;
    await _prefs.setTheme(dark ? 'dark' : 'light');
    notifyListeners();
  }
}
