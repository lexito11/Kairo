import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/prefs_service.dart';

class SavedPostsRepository {
  SavedPostsRepository({SupabaseClient? client, PrefsService? prefs})
      : _client = client ?? Supabase.instance.client,
        _prefs = prefs ?? PrefsService();

  final SupabaseClient _client;
  final PrefsService _prefs;
  var _migratedLocal = false;

  String? get _userId => _client.auth.currentUser?.id;

  Future<void> _migrateLocalOnce() async {
    if (_migratedLocal) return;
    _migratedLocal = true;
    final uid = _userId;
    if (uid == null) return;
    final local = await _prefs.getSavedPostIds();
    if (local.isEmpty) return;
    try {
      await _client.from('saved_posts').upsert(
            local.map((id) => {'user_id': uid, 'post_id': id}).toList(),
            onConflict: 'user_id,post_id',
          );
      await _prefs.clearSavedPostIds();
    } catch (_) {
      _migratedLocal = false;
    }
  }

  Future<List<String>> fetchIds() async {
    final uid = _userId;
    if (uid == null) return [];
    await _migrateLocalOnce();
    final rows = await _client
        .from('saved_posts')
        .select('post_id')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => r['post_id'] as String).toList();
  }

  Future<bool> isSaved(String postId) async {
    final uid = _userId;
    if (uid == null) return false;
    await _migrateLocalOnce();
    final row = await _client
        .from('saved_posts')
        .select('post_id')
        .eq('user_id', uid)
        .eq('post_id', postId)
        .maybeSingle();
    return row != null;
  }

  Future<bool> toggle(String postId) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');
    await _migrateLocalOnce();
    final already = await isSaved(postId);
    if (already) {
      await _client.from('saved_posts').delete().eq('user_id', uid).eq('post_id', postId);
      return false;
    }
    await _client.from('saved_posts').insert({'user_id': uid, 'post_id': postId});
    return true;
  }
}
