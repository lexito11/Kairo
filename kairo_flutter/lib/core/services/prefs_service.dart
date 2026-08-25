import 'package:shared_preferences/shared_preferences.dart';

import '../constants/chat_limits.dart';

enum PinChatResult { pinned, unpinned, limitReached }

class PrefsService {
  static const _savedPostsKey = 'saved-posts';
  static const _themeKey = 'theme';
  static const _rememberLoginKey = 'remember-login';
  static const _rememberedEmailKey = 'remembered-email';
  static const _rememberedPasswordKey = 'remembered-password';

  Future<bool> getRememberLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberLoginKey) ?? false;
  }

  Future<({String email, String password})?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rememberLoginKey) != true) return null;
    final email = prefs.getString(_rememberedEmailKey) ?? '';
    final password = prefs.getString(_rememberedPasswordKey) ?? '';
    if (email.isEmpty) return null;
    return (email: email, password: password);
  }

  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberLoginKey, true);
    await prefs.setString(_rememberedEmailKey, email.trim());
    await prefs.setString(_rememberedPasswordKey, password);
  }

  Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberLoginKey, false);
    await prefs.remove(_rememberedEmailKey);
    await prefs.remove(_rememberedPasswordKey);
  }

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

  static const _pinnedChatsKey = 'pinned-chats';

  Future<List<String>> getPinnedChatIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pinnedChatsKey) ?? [];
  }

  Future<PinChatResult> togglePinnedChat(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pinnedChatsKey) ?? [];
    if (list.contains(userId)) {
      list.remove(userId);
      await prefs.setStringList(_pinnedChatsKey, list);
      return PinChatResult.unpinned;
    }
    if (list.length >= ChatLimits.maxPinnedChats) {
      return PinChatResult.limitReached;
    }
    list.add(userId);
    await prefs.setStringList(_pinnedChatsKey, list);
    return PinChatResult.pinned;
  }

  Future<PinChatResult> setChatPinned(String userId, {required bool pin}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pinnedChatsKey) ?? [];
    final isPinned = list.contains(userId);
    if (pin) {
      if (isPinned) return PinChatResult.pinned;
      if (list.length >= ChatLimits.maxPinnedChats) {
        return PinChatResult.limitReached;
      }
      list.add(userId);
      await prefs.setStringList(_pinnedChatsKey, list);
      return PinChatResult.pinned;
    }
    if (!isPinned) return PinChatResult.unpinned;
    list.remove(userId);
    await prefs.setStringList(_pinnedChatsKey, list);
    return PinChatResult.unpinned;
  }

  Future<bool> isChatPinned(String userId) async {
    final list = await getPinnedChatIds();
    return list.contains(userId);
  }
}
