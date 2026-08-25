import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/comment.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/post.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/media_utils.dart';

const _postSelect = '''
  id, content, media_url, media_type, post_kind, created_at, author_id,
  author:users!posts_author_id_fkey(id, email, name, username, image, bio),
  likes(author_id),
  comments(count),
  intercessions(user_id)
''';

class PostsRepository {
  PostsRepository({SupabaseClient? client, StorageService? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage ?? StorageService();

  final SupabaseClient _client;
  final StorageService _storage;

  String? get _userId => _client.auth.currentUser?.id;

  Future<List<Post>> fetchFeed({int page = 1, int limit = 20, bool videoOnly = false}) async {
    final uid = _userId;
    final rows = await _client
        .from('posts')
        .select(_postSelect)
        .eq('is_anonymous', false)
        .order('created_at', ascending: false)
        .limit(250);

    var list = (rows as List)
        .map((r) => _mapPost(r as Map<String, dynamic>, uid))
        .toList();

    if (videoOnly) {
      list = list.where(postHasVideo).toList();
    }

    if (uid != null) {
      list = await _rankPosts(list, uid);
    }

    final start = (page - 1) * limit;
    final end = start + limit;
    if (start >= list.length) return [];
    return list.sublist(start, end > list.length ? list.length : end);
  }

  Future<List<Post>> fetchUserPosts(String userId) async {
    final rows = await _client
        .from('posts')
        .select(_postSelect)
        .eq('author_id', userId)
        .eq('is_anonymous', false)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).map((r) => _mapPost(r as Map<String, dynamic>, _userId)).toList();
  }

  Future<List<Post>> fetchMyPosts() async {
    final uid = _userId;
    if (uid == null) return [];
    return fetchUserPosts(uid);
  }

  Future<List<Post>> fetchPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _client.from('posts').select(_postSelect).inFilter('id', ids);
    final posts = (rows as List).map((r) => _mapPost(r as Map<String, dynamic>, _userId)).toList();
    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    posts.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
    return posts;
  }

  Future<Post> createPost({
    required String content,
    PostKind postKind = PostKind.post,
    List<({Uint8List bytes, String name, String mime})>? files,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    String? mediaUrl;
    String? mediaType;

    if (files != null && files.isNotEmpty) {
      final urls = <String>[];
      for (final f in files) {
        final url = await _storage.uploadBytes(
          bytes: f.bytes,
          fileName: f.name,
          mimeType: f.mime,
        );
        urls.add(url);
      }
      mediaUrl = urls.length == 1 ? urls.first : jsonEncode(urls);
      final firstVideo = files.any((f) => f.mime.startsWith('video/'));
      mediaType = firstVideo ? 'video' : 'image';
    }

    final row = await _client.from('posts').insert({
      'content': content,
      'author_id': uid,
      'is_anonymous': false,
      'post_kind': postKindToString(postKind),
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
    }).select(_postSelect).single();

    return _mapPost(row, uid);
  }

  Future<Post> updatePostContent(String postId, String content) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    final row = await _client
        .from('posts')
        .update({'content': content})
        .eq('id', postId)
        .eq('author_id', uid)
        .select(_postSelect)
        .single();

    return _mapPost(row, uid);
  }

  Future<void> deletePost(String postId) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    await _client.from('posts').delete().eq('id', postId).eq('author_id', uid);
  }

  Future<bool> toggleLike(String postId) async {
    final uid = _userId;
    if (uid == null) return false;

    final existing = await _client
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .eq('author_id', uid)
        .maybeSingle();

    if (existing != null) {
      await _client.from('likes').delete().eq('id', existing['id']);
      return false;
    }
    await _client.from('likes').insert({'post_id': postId, 'author_id': uid});
    return true;
  }

  Future<List<KairoUser>> fetchPostLikers(String postId) async {
    final rows = await _client
        .from('likes')
        .select('created_at, author:users!likes_author_id_fkey(id, email, name, username, image)')
        .eq('post_id', postId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => KairoUser.fromJson(r['author'] as Map<String, dynamic>))
        .toList();
  }

  /// Prioriza un seguidor tuyo que dio Amén; si no hay, el más reciente.
  Future<({List<KairoUser> likers, KairoUser? featured})> fetchPostLikersSummary(String postId) async {
    final likers = await fetchPostLikers(postId);
    if (likers.isEmpty) return (likers: likers, featured: null);

    final uid = _userId;
    if (uid != null) {
      final followerRows = await _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', uid);
      final followerIds = (followerRows as List).map((r) => r['follower_id'] as String).toSet();
      for (final liker in likers) {
        if (followerIds.contains(liker.id)) {
          return (likers: likers, featured: liker);
        }
      }
    }

    return (likers: likers, featured: likers.first);
  }

  Future<List<Comment>> fetchComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select('id, content, created_at, author:users!comments_author_id_fkey(id, email, name, username, image)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return (rows as List).map((r) => Comment.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Comment> addComment(String postId, String content) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    final row = await _client.from('comments').insert({
      'post_id': postId,
      'author_id': uid,
      'content': content,
    }).select('id, content, created_at, author:users!comments_author_id_fkey(id, email, name, username, image)').single();

    return Comment.fromJson(row);
  }

  Future<bool> toggleIntercede(String postId) async {
    final uid = _userId;
    if (uid == null) return false;

    final existing = await _client
        .from('intercessions')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null) {
      await _client.from('intercessions').delete().eq('id', existing['id']);
      return false;
    }
    await _client.from('intercessions').insert({'post_id': postId, 'user_id': uid});
    return true;
  }

  Future<void> recordView(String postId, int watchedSeconds) async {
    final uid = _userId;
    if (uid == null) return;
    await _client.from('post_views').insert({
      'post_id': postId,
      'user_id': uid,
      'watched_seconds': watchedSeconds,
    });
  }

  Post _mapPost(Map<String, dynamic> json, String? currentUserId) {
    final likes = json['likes'] as List?;
    final intercessions = json['intercessions'] as List?;
    final commentsAgg = json['comments'] as List?;
    int commentsCount = 0;
    if (commentsAgg != null && commentsAgg.isNotEmpty) {
      commentsCount = (commentsAgg.first as Map)['count'] as int? ?? 0;
    }

    final mapped = Map<String, dynamic>.from(json);
    mapped['_count'] = {
      'likes': likes?.length ?? 0,
      'comments': commentsCount,
      'intercessions': intercessions?.length ?? 0,
    };
    return Post.fromJson(mapped, currentUserId: currentUserId);
  }

  Future<List<Post>> _rankPosts(List<Post> pool, String userId) async {
    final following = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final followingIds = (following as List).map((r) => r['following_id'] as String).toSet();

    final likes = await _client.from('likes').select('post_id').eq('author_id', userId);
    final likedPostIds = (likes as List).map((r) => r['post_id'] as String).toList();

    final comments = await _client.from('comments').select('post_id').eq('author_id', userId);
    final commentedPostIds = (comments as List).map((r) => r['post_id'] as String).toList();

    final engagedAuthorIds = <String>{};
    for (final p in pool) {
      if (likedPostIds.contains(p.id) || commentedPostIds.contains(p.id)) {
        engagedAuthorIds.add(p.author.id);
      }
    }

    final views = await _client
        .from('post_views')
        .select('watched_seconds, post:posts(author_id)')
        .eq('user_id', userId);
    final authorWatch = <String, int>{};
    for (final v in views as List) {
      final post = v['post'] as Map<String, dynamic>?;
      final aid = post?['author_id'] as String?;
      if (aid != null) {
        authorWatch[aid] = (authorWatch[aid] ?? 0) + (v['watched_seconds'] as int? ?? 0);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final scored = pool.map((post) {
      var score = 0.0;
      if (followingIds.contains(post.author.id)) score += 1000;
      if (engagedAuthorIds.contains(post.author.id)) score += 350;
      final watchSec = authorWatch[post.author.id] ?? 0;
      score += (watchSec / 60 * 12).clamp(0, 400);
      final hours = now - post.createdAt.millisecondsSinceEpoch;
      final hoursSince = hours / (1000 * 60 * 60);
      score += 80 * (hoursSince > 0 ? (1 / (1 + hoursSince / 48)) : 1);
      score += (post.likesCount + post.commentsCount * 2).clamp(0, 120) * 0.5;
      if (postHasVideo(post)) score *= 1.15;
      return (post, score);
    }).toList();

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }
}
