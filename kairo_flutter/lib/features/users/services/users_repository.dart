import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/kairo_user.dart';

class UserProfileData {
  const UserProfileData({
    required this.user,
    required this.agregados,
    required this.teAgregaron,
    required this.viewerHasAdded,
    this.friendsCount = 0,
  });

  final KairoUser user;
  final int agregados;
  final int teAgregaron;
  final bool viewerHasAdded;
  final int friendsCount;
}

class FollowNotification {
  const FollowNotification({
    required this.id,
    required this.follower,
    required this.createdAt,
    required this.isUnread,
    required this.viewerHasAddedBack,
  });

  final String id;
  final KairoUser follower;
  final DateTime createdAt;
  final bool isUnread;
  final bool viewerHasAddedBack;
}

class UsersRepository {
  UsersRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<KairoUser?> getCurrentUser() async {
    final uid = _userId;
    if (uid == null) return null;
    final row = await _client.from('users').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return KairoUser.fromJson(row);
  }

  Future<UserProfileData> getUserProfile(String userId) async {
    final userRow = await _client.from('users').select('id, email, name, username, image, bio, mood').eq('id', userId).single();
    final user = KairoUser.fromJson(userRow);

    final agregados = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', userId);
    final teAgregaron = await _client
        .from('follows')
        .select('id')
        .eq('following_id', userId);

    var viewerHasAdded = false;
    final uid = _userId;
    if (uid != null && uid != userId) {
      final row = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', uid)
          .eq('following_id', userId)
          .maybeSingle();
      viewerHasAdded = row != null;
    }

    final friendsCount = uid == userId ? await _countFriends(userId) : 0;

    return UserProfileData(
      user: user,
      agregados: (agregados as List).length,
      teAgregaron: (teAgregaron as List).length,
      viewerHasAdded: viewerHasAdded,
      friendsCount: friendsCount,
    );
  }

  Future<int> _countFriends(String userId) async {
    final following = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final followingIds = (following as List).map((r) => r['following_id'] as String).toSet();
    if (followingIds.isEmpty) return 0;

    final followers = await _client
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId);
    return (followers as List)
        .where((r) => followingIds.contains(r['follower_id']))
        .length;
  }

  Future<void> follow(String userId) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');
    await _client.from('follows').insert({'follower_id': uid, 'following_id': userId});
  }

  Future<void> unfollow(String userId) async {
    final uid = _userId;
    if (uid == null) return;
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', uid)
        .eq('following_id', userId);
  }

  Future<({int unreadCount, int friendsCount})> getSocialSummary() async {
    final uid = _userId;
    if (uid == null) return (unreadCount: 0, friendsCount: 0);

    final unread = await _client
        .from('follows')
        .select('id')
        .eq('following_id', uid)
        .isFilter('seen_by_followee_at', null);

    return (
      unreadCount: (unread as List).length,
      friendsCount: await _countFriends(uid),
    );
  }

  Future<List<FollowNotification>> getNotifications() async {
    final uid = _userId;
    if (uid == null) return [];

    final rows = await _client
        .from('follows')
        .select('id, created_at, seen_by_followee_at, follower:users!follows_follower_id_fkey(id, email, name, username, image)')
        .eq('following_id', uid)
        .order('created_at', ascending: false)
        .limit(50);

    final myFollowing = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    final followingIds = (myFollowing as List).map((r) => r['following_id'] as String).toSet();

    return (rows as List).map((r) {
      final followerJson = r['follower'] as Map<String, dynamic>;
      final followerId = followerJson['id'] as String;
      return FollowNotification(
        id: r['id'] as String,
        follower: KairoUser.fromJson(followerJson),
        createdAt: DateTime.parse(r['created_at'] as String),
        isUnread: r['seen_by_followee_at'] == null,
        viewerHasAddedBack: followingIds.contains(followerId),
      );
    }).toList();
  }

  Future<void> markNotificationsSeen() async {
    final uid = _userId;
    if (uid == null) return;
    await _client
        .from('follows')
        .update({'seen_by_followee_at': DateTime.now().toIso8601String()})
        .eq('following_id', uid)
        .isFilter('seen_by_followee_at', null);
  }

  Future<List<KairoUser>> getContacts() async {
    final uid = _userId;
    if (uid == null) return [];

    final rows = await _client
        .from('follows')
        .select('following:users!follows_following_id_fkey(id, email, name, username, image)')
        .eq('follower_id', uid);

    return (rows as List)
        .map((r) => KairoUser.fromJson(r['following'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateMood(String mood) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');
    await _client.from('users').update({
      'mood': mood,
      'mood_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', uid);
  }

  Future<void> updateProfile({String? name, String? username, String? bio, String? image}) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');
    await _client.from('users').update({
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
      if (image != null) 'image': image,
    }).eq('id', uid);
  }
}
