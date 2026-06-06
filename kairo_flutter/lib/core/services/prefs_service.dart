import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _savedPostsKey = 'saved-posts';
  static const _themeKey = 'theme';

  Future<List<String>> getSavedPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedPostsKey) ?? [];
  }

  Future<bool> toggleSavedPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_savedPostsKey) ?? [];
    if (list.contains(postId)) {
      list.remove(postId);
    } else {
      list.add(postId);
    }
    await prefs.setStringList(_savedPostsKey, list);
    return list.contains(postId);
  }

  Future<bool> isPostSaved(String postId) async {
    final list = await getSavedPostIds();
    return list.contains(postId);
  }

  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'dark';
  }

  Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }
}
