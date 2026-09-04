import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BibleTextSizeStore extends ChangeNotifier {
  BibleTextSizeStore._() {
    _load();
  }

  static final BibleTextSizeStore instance = BibleTextSizeStore._();

  static const minSize = 14.0;
  static const maxSize = 28.0;
  static const step = 2.0;
  static const defaultSize = 16.0;
  static const _key = 'bible-text-size';

  double size = defaultSize;

  bool get canDecrease => size > minSize + 0.01;
  bool get canIncrease => size < maxSize - 0.01;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_key);
    if (stored == null) return;
    size = stored.clamp(minSize, maxSize);
    notifyListeners();
  }

  Future<void> decrease() async {
    if (!canDecrease) return;
    size = (size - step).clamp(minSize, maxSize);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, size);
  }

  Future<void> increase() async {
    if (!canIncrease) return;
    size = (size + step).clamp(minSize, maxSize);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, size);
  }
}
