import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/kairo_user.dart';
import '../../../core/models/profile_moment.dart';
import '../../../core/services/storage_service.dart';

class MomentsRepository {
  MomentsRepository({SupabaseClient? client, StorageService? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage ?? StorageService();

  final SupabaseClient _client;
  final StorageService _storage;
  static const _uuid = Uuid();

  String? get _uid => _client.auth.currentUser?.id;

  String _prefsKey(String userId) => 'profile-moments-$userId';

  Future<List<ProfileMoment>> list(String userId) async {
    try {
      final rows = await _client
          .from('profile_moments')
          .select(
              'id, user_id, title, icon_id, cover_url, sort_order, profile_moment_items(id, media_url, media_type, story_id, created_at, sort_order)')
          .eq('user_id', userId)
          .order('sort_order')
          .timeout(const Duration(seconds: 4));
      final moments = (rows as List).cast<Map<String, dynamic>>().map(_fromRemote).toList();
      await _saveLocal(userId, moments);
      return moments;
    } catch (_) {
      try {
        final rows = await _client
            .from('profile_moments')
            .select(
                'id, user_id, title, icon_id, sort_order, profile_moment_items(id, media_url, media_type, story_id, created_at, sort_order)')
            .eq('user_id', userId)
            .order('sort_order')
            .timeout(const Duration(seconds: 4));
        final moments = (rows as List).cast<Map<String, dynamic>>().map(_fromRemote).toList();
        await _saveLocal(userId, moments);
        return moments;
      } catch (_) {
        return _loadLocal(userId);
      }
    }
  }

  Future<ProfileMoment> create({
    required String title,
    required String iconId,
    required List<MomentItem> items,
    String? coverImageUrl,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Debes iniciar sesión');
    final existing = await list(uid);
    final moment = ProfileMoment(
      id: _uuid.v4(),
      userId: uid,
      title: title.trim().isEmpty ? 'Momento' : title.trim(),
      iconId: iconId,
      items: items,
      sortOrder: existing.length,
      coverImageUrl: coverImageUrl,
    );
    try {
      await _client.from('profile_moments').insert({
        'id': moment.id,
        'user_id': uid,
        'title': moment.title,
        'icon_id': moment.iconId,
        'cover_url': coverImageUrl,
        'sort_order': moment.sortOrder,
      });
      if (items.isNotEmpty) {
        await _client.from('profile_moment_items').insert([
          for (var i = 0; i < items.length; i++)
            {
              'id': items[i].id,
              'moment_id': moment.id,
              'media_url': items[i].mediaUrl,
              'media_type': items[i].mediaType,
              'story_id': items[i].storyId,
              'sort_order': i,
            },
        ]);
      }
    } catch (_) {
      try {
        await _client.from('profile_moments').insert({
          'id': moment.id,
          'user_id': uid,
          'title': moment.title,
          'icon_id': moment.iconId,
          'sort_order': moment.sortOrder,
        });
      } catch (_) {}
    }
    final next = [...existing.where((m) => m.id != moment.id), moment];
    await _saveLocal(uid, next);
    return moment;
  }

  Future<void> addItems(String momentId, List<MomentItem> items) async {
    final uid = _uid;
    if (uid == null || items.isEmpty) return;
    try {
      await _client.from('profile_moment_items').insert([
        for (var i = 0; i < items.length; i++)
          {
            'id': items[i].id,
            'moment_id': momentId,
            'media_url': items[i].mediaUrl,
            'media_type': items[i].mediaType,
            'story_id': items[i].storyId,
            'sort_order': i,
          },
      ]);
    } catch (_) {}
    final current = await _loadLocal(uid);
    final next = current
        .map((m) => m.id == momentId ? m.copyWith(items: [...m.items, ...items]) : m)
        .toList();
    await _saveLocal(uid, next);
  }

  Future<void> updateMeta({
    required String momentId,
    required String title,
    required String iconId,
    String? coverImageUrl,
    bool clearCover = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('profile_moments').update({
        'title': title.trim(),
        'icon_id': iconId,
        'cover_url': clearCover ? null : coverImageUrl,
      }).eq('id', momentId);
    } catch (_) {
      try {
        await _client.from('profile_moments').update({
          'title': title.trim(),
          'icon_id': iconId,
        }).eq('id', momentId);
      } catch (_) {}
    }
    final current = await _loadLocal(uid);
    final next = current
        .map(
          (m) => m.id == momentId
              ? m.copyWith(
                  title: title.trim(),
                  iconId: iconId,
                  coverImageUrl: coverImageUrl,
                  clearCover: clearCover,
                )
              : m,
        )
        .toList();
    await _saveLocal(uid, next);
  }

  Future<void> replaceItems(String momentId, List<MomentItem> items) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('profile_moment_items').delete().eq('moment_id', momentId);
      if (items.isNotEmpty) {
        await _client.from('profile_moment_items').insert([
          for (var i = 0; i < items.length; i++)
            {
              'id': items[i].id,
              'moment_id': momentId,
              'media_url': items[i].mediaUrl,
              'media_type': items[i].mediaType,
              'story_id': items[i].storyId,
              'sort_order': i,
            },
        ]);
      }
    } catch (_) {}
    final current = await _loadLocal(uid);
    final next = current.map((m) => m.id == momentId ? m.copyWith(items: items) : m).toList();
    await _saveLocal(uid, next);
  }

  Future<void> removeItem(String momentId, String itemId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('profile_moment_items').delete().eq('id', itemId);
    } catch (_) {}
    final current = await _loadLocal(uid);
    final next = <ProfileMoment>[];
    for (final moment in current) {
      if (moment.id != momentId) {
        next.add(moment);
        continue;
      }
      final items = moment.items.where((e) => e.id != itemId).toList();
      if (items.isEmpty) {
        try {
          await _client.from('profile_moments').delete().eq('id', momentId);
        } catch (_) {}
        continue;
      }
      next.add(moment.copyWith(items: items));
    }
    await _saveLocal(uid, next);
  }

  Future<void> delete(String momentId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('profile_moments').delete().eq('id', momentId);
    } catch (_) {}
    final next = (await _loadLocal(uid)).where((m) => m.id != momentId).toList();
    await _saveLocal(uid, next);
  }

  Future<String> uploadCover({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return _storage.uploadBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'image/jpeg',
      subfolder: 'moment-covers',
    );
  }

  MomentItem itemFromStory({
    required String storyId,
    required String mediaUrl,
    required String mediaType,
  }) {
    return MomentItem(
      id: _uuid.v4(),
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      storyId: storyId,
      createdAt: DateTime.now(),
    );
  }

  Future<Set<String>> likedItemIds(Iterable<String> itemIds) async {
    final uid = _uid;
    final ids = itemIds.toList();
    if (uid == null || ids.isEmpty) return {};
    try {
      final rows = await _client
          .from('moment_item_likes')
          .select('item_id')
          .eq('user_id', uid)
          .inFilter('item_id', ids);
      return {for (final row in rows as List) (row as Map)['item_id'] as String};
    } catch (_) {
      return {};
    }
  }

  Future<bool> toggleItemLike(String itemId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Debes iniciar sesión');
    final existing = await _client
        .from('moment_item_likes')
        .select('id')
        .eq('item_id', itemId)
        .eq('user_id', uid)
        .maybeSingle();
    if (existing != null) {
      await _client.from('moment_item_likes').delete().eq('id', existing['id']);
      return false;
    }
    await _client.from('moment_item_likes').insert({
      'item_id': itemId,
      'user_id': uid,
    });
    return true;
  }

  Future<List<KairoUser>> fetchItemLikers(String itemId) async {
    try {
      final rows = await _client
          .from('moment_item_likes')
          .select('user_id, users:user_id(id, email, name, username, image)')
          .eq('item_id', itemId)
          .order('created_at', ascending: false);
      final likers = <KairoUser>[];
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final user = map['users'];
        if (user is Map) {
          likers.add(KairoUser.fromJson(Map<String, dynamic>.from(user)));
        }
      }
      return likers;
    } catch (_) {
      return const [];
    }
  }

  ProfileMoment _fromRemote(Map<String, dynamic> row) {
    final rawItems = row['profile_moment_items'] as List? ?? const [];
    final items = rawItems.whereType<Map>().map((e) {
      final map = Map<String, dynamic>.from(e);
      return MomentItem.fromJson(map);
    }).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return ProfileMoment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String? ?? '',
      iconId: row['icon_id'] as String? ?? 'star',
      coverImageUrl: row['cover_url'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }

  Future<List<ProfileMoment>> _loadLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => ProfileMoment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocal(String userId, List<ProfileMoment> moments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey(userId),
      jsonEncode(moments.map((e) => e.toJson()).toList()),
    );
  }
}
