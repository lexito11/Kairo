import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible_book.dart';

class BibleSavedStore {
  BibleSavedStore._();
  static final BibleSavedStore instance = BibleSavedStore._();

  static const _key = 'bible-saved-verses';

  Future<List<BibleCitation>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final items = <BibleCitation>[];
    for (final row in raw) {
      try {
        items.add(BibleCitation.fromJson(jsonDecode(row) as Map<String, dynamic>));
      } catch (_) {}
    }
    items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }

  Future<bool> isSaved(BibleCitation citation) async {
    final items = await list();
    return items.any((e) => e.id == citation.id);
  }

  Future<bool> toggle(BibleCitation citation) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await list();
    final exists = items.any((e) => e.id == citation.id);
    if (exists) {
      items.removeWhere((e) => e.id == citation.id);
    } else {
      items.insert(0, citation.withSavedAt(DateTime.now().millisecondsSinceEpoch));
    }
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
    return !exists;
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await list()..removeWhere((e) => e.id == id);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
  }
}
