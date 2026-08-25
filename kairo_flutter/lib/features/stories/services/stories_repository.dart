import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/story.dart';
import '../../../core/services/storage_service.dart';

class StoriesRepository {
  StoriesRepository({SupabaseClient? client, StorageService? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage ?? StorageService();

  final SupabaseClient _client;
  final StorageService _storage;
  String? get _userId => _client.auth.currentUser?.id;

  Future<List<StoryGroup>> fetchStoryGroups() async {
    final uid = _userId;
    if (uid == null) return [];

    final friendRows = await _client
        .rpc('get_mutual_friend_stories', params: {'viewer_id': uid});
    List myRows;
    try {
      myRows = await _client
          .from('stories')
          .select(
              'id, media_url, media_type, created_at, expires_at, author_id, sound_name')
          .eq('author_id', uid)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);
    } catch (_) {
      myRows = await _client
          .from('stories')
          .select(
              'id, media_url, media_type, created_at, expires_at, author_id')
          .eq('author_id', uid)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);
    }

    final rawStories = <Map<String, dynamic>>[
      ...(friendRows as List? ?? []).cast<Map<String, dynamic>>(),
      ...(myRows).cast<Map<String, dynamic>>(),
    ];

    if (rawStories.isEmpty) return [];

    final authorIds =
        rawStories.map((r) => r['author_id'] as String).toSet().toList();
    final users = await _client
        .from('users')
        .select('id, email, name, username, image')
        .inFilter('id', authorIds);
    final userMap = {
      for (final u in users as List)
        (u as Map)['id'] as String:
            KairoUser.fromJson(u as Map<String, dynamic>),
    };

    final allStories = <Story>[];
    for (final r in rawStories) {
      final copy = Map<String, dynamic>.from(r);
      final author = userMap[r['author_id'] as String];
      if (author == null) continue;
      copy['author'] = author.toJson();
      allStories.add(Story.fromJson(copy));
    }

    final groups = <String, List<Story>>{};
    for (final s in allStories) {
      groups.putIfAbsent(s.author.id, () => []).add(s);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return groups.entries
        .map((e) => StoryGroup(author: e.value.first.author, stories: e.value))
        .toList();
  }

  Future<Story> publishStory({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    final url = await _storage.uploadBytes(
        bytes: bytes, fileName: fileName, mimeType: mimeType);
    final isVideo = mimeType.startsWith('video/');

    final row = await _client
        .from('stories')
        .insert({
          'author_id': uid,
          'media_url': url,
          'media_type': isVideo ? 'video' : 'image',
        })
        .select()
        .single();

    final user = await _client
        .from('users')
        .select('id, email, name, username, image')
        .eq('id', uid)
        .single();
    final mapped = Map<String, dynamic>.from(row);
    mapped['author'] = user;
    return Story.fromJson(mapped);
  }

  Future<Set<String>> likedStoryIds(Iterable<String> storyIds) async {
    final uid = _userId;
    final ids = storyIds.toList();
    if (uid == null || ids.isEmpty) return {};

    try {
      final rows = await _client
          .from('story_likes')
          .select('story_id')
          .eq('author_id', uid)
          .inFilter('story_id', ids);
      return {
        for (final row in rows as List) (row as Map)['story_id'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  Future<bool> toggleLike(String storyId) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    final existing = await _client
        .from('story_likes')
        .select('id')
        .eq('story_id', storyId)
        .eq('author_id', uid)
        .maybeSingle();

    if (existing != null) {
      await _client.from('story_likes').delete().eq('id', existing['id']);
      return false;
    }

    await _client.from('story_likes').insert({
      'story_id': storyId,
      'author_id': uid,
    });
    return true;
  }
}
