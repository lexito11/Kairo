import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/utils/username.dart';

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

  UserProfileData copyWith({KairoUser? user}) {
    return UserProfileData(
      user: user ?? this.user,
      agregados: agregados,
      teAgregaron: teAgregaron,
      viewerHasAdded: viewerHasAdded,
      friendsCount: friendsCount,
    );
  }
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

/// Entrada de la sección Personas (follows / amigos).
class PersonaEntry {
  const PersonaEntry({
    required this.user,
    required this.followedAt,
    required this.iFollowThem,
    required this.theyFollowMe,
    this.mutualCount = 0,
  });

  final KairoUser user;
  final DateTime? followedAt;
  final bool iFollowThem;
  final bool theyFollowMe;
  final int mutualCount;

  bool get isFriend => iFollowThem && theyFollowMe;
  bool get isPendingOutgoing => iFollowThem && !theyFollowMe;
  bool get isIncomingPending => theyFollowMe && !iFollowThem;

  String get subtitle {
    final bio = user.bio?.trim();
    if (bio != null && bio.isNotEmpty) return bio;
    if (user.username != null && user.username!.isNotEmpty) return '@${user.username}';
    return 'Miembro de KAIRO';
  }
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
    final userRow = await _client.from('users').select().eq('id', userId).maybeSingle();
    if (userRow == null) {
      throw Exception('No se encontró el perfil');
    }
    final user = KairoUser.fromJson(userRow);

    var agregados = 0;
    var teAgregaron = 0;
    var viewerHasAdded = false;
    var friendsCount = 0;
    try {
      final added = await _client.from('follows').select('id').eq('follower_id', userId);
      agregados = (added as List).length;
      final incoming = await _client.from('follows').select('id').eq('following_id', userId);
      teAgregaron = (incoming as List).length;
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
      if (uid == userId) {
        friendsCount = await _countFriends(userId);
      }
    } catch (_) {}

    return UserProfileData(
      user: user,
      agregados: agregados,
      teAgregaron: teAgregaron,
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

  Future<Set<String>> fetchFollowingIds() async {
    final uid = _userId;
    if (uid == null) return {};
    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    return (rows as List).map((r) => r['following_id'] as String).toSet();
  }

  Future<({int unreadCount, int friendsCount})> getSocialSummary() async {
    final uid = _userId;
    if (uid == null) return (unreadCount: 0, friendsCount: 0);

    var inviteCount = 0;
    try {
      final unreadInvites = await _client
          .from('chat_group_invites')
          .select('id')
          .eq('invitee_id', uid)
          .eq('status', 'pending')
          .isFilter('seen_at', null);
      inviteCount = (unreadInvites as List).length;
    } catch (_) {}

    var unreadFollowCount = 0;
    try {
      final unreadFollows = await _client
          .from('follows')
          .select('id')
          .eq('following_id', uid)
          .isFilter('seen_by_followee_at', null);
      unreadFollowCount = (unreadFollows as List).length;
    } catch (_) {}

    var friendsCount = 0;
    try {
      friendsCount = await _countFriends(uid);
    } catch (_) {}

    return (
      unreadCount: unreadFollowCount + inviteCount,
      friendsCount: friendsCount,
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
        .select('following:users!follows_following_id_fkey(id, email, name, username, image, bio)')
        .eq('follower_id', uid);

    return (rows as List)
        .map((r) => KairoUser.fromJson(r['following'] as Map<String, dynamic>))
        .toList();
  }

  /// Personas que te siguen (Me agregaron).
  Future<List<PersonaEntry>> getIncomingFollows() async {
    final uid = _userId;
    if (uid == null) return [];

    final rows = await _client
        .from('follows')
        .select(
          'id, created_at, follower:users!follows_follower_id_fkey(id, email, name, username, image, bio)',
        )
        .eq('following_id', uid)
        .order('created_at', ascending: false);

    final followingIds = await fetchFollowingIds();
    final list = <PersonaEntry>[];
    for (final r in rows as List) {
      final follower = KairoUser.fromJson(r['follower'] as Map<String, dynamic>);
      list.add(PersonaEntry(
        user: follower,
        followedAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
        iFollowThem: followingIds.contains(follower.id),
        theyFollowMe: true,
      ));
    }
    await _attachMutualCounts(list);
    return list;
  }

  /// Personas que tú seguiste (Agregados).
  Future<List<PersonaEntry>> getOutgoingFollows() async {
    final uid = _userId;
    if (uid == null) return [];

    final rows = await _client
        .from('follows')
        .select(
          'id, created_at, following:users!follows_following_id_fkey(id, email, name, username, image, bio)',
        )
        .eq('follower_id', uid)
        .order('created_at', ascending: false);

    final followerIds = await _fetchFollowerIds();
    final list = <PersonaEntry>[];
    for (final r in rows as List) {
      final user = KairoUser.fromJson(r['following'] as Map<String, dynamic>);
      list.add(PersonaEntry(
        user: user,
        followedAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
        iFollowThem: true,
        theyFollowMe: followerIds.contains(user.id),
      ));
    }
    await _attachMutualCounts(list);
    return list;
  }

  /// Amigos = seguimiento mutuo.
  Future<List<PersonaEntry>> getFriends() async {
    final outgoing = await getOutgoingFollows();
    return outgoing.where((e) => e.isFriend).toList();
  }

  Future<List<KairoUser>> searchUsers(String query, {int limit = 20}) async {
    final uid = _userId;
    final q = query.trim();
    if (uid == null || q.length < 2) return [];

    final sanitized = q.replaceAll(RegExp(r'[%_,]'), ' ').trim();
    if (sanitized.length < 2) return [];

    final rows = await _client
        .from('users')
        .select('id, email, name, username, image')
        .neq('id', uid)
        .or('name.ilike.%$sanitized%,username.ilike.%$sanitized%')
        .limit(limit);

    return (rows as List)
        .map((r) => KairoUser.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Quitar a alguien que te sigue (Eliminar solicitud / seguidor).
  Future<void> removeFollower(String followerId) async {
    final uid = _userId;
    if (uid == null) return;
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', uid);
  }

  Future<Set<String>> _fetchFollowerIds() async {
    final uid = _userId;
    if (uid == null) return {};
    final rows = await _client
        .from('follows')
        .select('follower_id')
        .eq('following_id', uid);
    return (rows as List).map((r) => r['follower_id'] as String).toSet();
  }

  Future<void> _attachMutualCounts(List<PersonaEntry> entries) async {
    if (entries.isEmpty) return;
    final uid = _userId;
    if (uid == null) return;

    final myFollowing = await fetchFollowingIds();
    if (myFollowing.isEmpty) return;

    final targetIds = entries.map((e) => e.user.id).toList();
    final rows = await _client
        .from('follows')
        .select('follower_id, following_id')
        .inFilter('following_id', targetIds)
        .inFilter('follower_id', myFollowing.toList());

    final counts = <String, int>{};
    for (final r in rows as List) {
      final target = r['following_id'] as String;
      final follower = r['follower_id'] as String;
      if (follower == uid) continue;
      counts[target] = (counts[target] ?? 0) + 1;
    }

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      entries[i] = PersonaEntry(
        user: e.user,
        followedAt: e.followedAt,
        iFollowThem: e.iFollowThem,
        theyFollowMe: e.theyFollowMe,
        mutualCount: counts[e.user.id] ?? 0,
      );
    }
  }

  Future<void> updateMood(String mood) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');
    final row = await _client.from('users').select('mood_updated_at').eq('id', uid).maybeSingle();
    final last = DateTime.tryParse(row?['mood_updated_at']?.toString() ?? '');
    if (last != null && DateTime.now().toUtc().difference(last.toUtc()) < KairoUser.moodLockDuration) {
      throw Exception('Podrás cambiar cómo te sientes después de 24 horas');
    }
    await _client.from('users').update({
      'mood': mood,
      'mood_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Future<bool> getSaveStoryArchive() async {
    final uid = _userId;
    if (uid == null) return true;
    try {
      final row = await _client.from('users').select('save_story_archive').eq('id', uid).maybeSingle();
      return row?['save_story_archive'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> updateSaveStoryArchive(bool value) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');
    await _client.from('users').update({'save_story_archive': value}).eq('id', uid);
  }

  Future<bool> isUsernameTaken(String username) async {
    final uid = _userId;
    if (username.isEmpty) return false;
    final row = await _client.from('users').select('id').eq('username', username).maybeSingle();
    if (row == null) return false;
    return row['id'] != uid;
  }

  Future<String> generateAvailableUsername(String seed) async {
    var base = UsernamePolicy.sanitize(seed);
    if (base.length < UsernamePolicy.minLength) base = UsernamePolicy.seedFromEmail(seed);
    var candidate = base;
    var i = 0;
    while (await isUsernameTaken(candidate)) {
      i++;
      final suffix = i.toString();
      final keep = (UsernamePolicy.maxLength - suffix.length).clamp(1, base.length);
      candidate = '${base.substring(0, keep)}$suffix';
      if (i > 80) {
        candidate = 'user${DateTime.now().millisecondsSinceEpoch % 100000}';
        break;
      }
    }
    return candidate;
  }

  Future<KairoUser> ensureGeneratedUsername(KairoUser user) async {
    final current = user.username?.trim();
    if (current != null && current.isNotEmpty) return user;
    final generated = await generateAvailableUsername(UsernamePolicy.seedFromEmail(user.email));
    await _client.from('users').update({'username': generated}).eq('id', user.id);
    return user.copyWith(username: generated);
  }

  String _mapProfileError(PostgrestException e) {
    final code = e.code ?? '';
    final message = e.message;
    if (code == '23505' || message.contains('users_username')) {
      return 'Ese nombre de usuario ya está en uso';
    }
    if (message.contains('USERNAME_COOLDOWN') || code == 'P0001') {
      return 'El usuario se cambia una sola vez cada 6 meses';
    }
    if (message.contains('USERNAME_INVALID')) {
      return 'El usuario debe tener entre 3 y 20 caracteres (letras, números o _)';
    }
    return message.isNotEmpty ? message : 'No se pudo guardar el perfil';
  }

  Future<void> updateProfile({String? name, String? username, String? bio, String? image, String? coverUrl}) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (image != null) 'image': image,
      if (coverUrl != null) 'cover_url': coverUrl,
    };

    if (username != null) {
      final cleaned = UsernamePolicy.sanitize(username);
      final invalid = UsernamePolicy.validate(cleaned);
      if (invalid != null) throw Exception(invalid);

      final current = await getCurrentUser();
      final currentName = current?.username?.trim() ?? '';
      if (cleaned != currentName) {
        if (!UsernamePolicy.canChange(current?.usernameChangedAt)) {
          throw Exception(UsernamePolicy.cooldownMessage(current!.usernameChangedAt!));
        }
        if (await isUsernameTaken(cleaned)) {
          throw Exception('Ese nombre de usuario ya está en uso');
        }
        payload['username'] = cleaned;
        if (currentName.isNotEmpty) {
          payload['username_changed_at'] = DateTime.now().toUtc().toIso8601String();
        }
      }
    }

    if (payload.isEmpty) return;
    try {
      await _client.from('users').update(payload).eq('id', uid);
    } on PostgrestException catch (e) {
      final missingColumn = e.code == '42703' ||
          e.message.contains('username_changed_at') ||
          e.message.contains('cover_url');
      if (missingColumn && (payload.containsKey('username_changed_at') || payload.containsKey('cover_url'))) {
        payload.remove('username_changed_at');
        payload.remove('cover_url');
        if (payload.isEmpty) {
          throw Exception('No se pudo guardar la portada. Ejecuta en Supabase la migración 020_profile_cover.sql');
        }
        try {
          await _client.from('users').update(payload).eq('id', uid);
          return;
        } on PostgrestException catch (retry) {
          throw Exception(_mapProfileError(retry));
        }
      }
      throw Exception(_mapProfileError(e));
    }
  }
}
