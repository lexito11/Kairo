import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/chat_limits.dart';
import '../../../core/models/chat_group.dart';
import '../../../core/models/group_invite.dart';
import '../../../core/services/storage_service.dart';

class GroupsRepository {
  GroupsRepository({SupabaseClient? client, StorageService? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage ?? StorageService();

  final SupabaseClient _client;
  final StorageService _storage;
  String? get _userId => _client.auth.currentUser?.id;

  static const _groupFields =
      'id, name, created_at, created_by, member_count, is_public, admins_only_chat';

  Future<int> _adminCount(String groupId) async {
    final rows = await _client
        .from('chat_group_members')
        .select('user_id')
        .eq('group_id', groupId)
        .eq('role', 'admin');
    return (rows as List).length;
  }

  Future<Map<String, dynamic>> _attachAdminCount(Map<String, dynamic> map) async {
    map['admin_count'] = await _adminCount(map['id'] as String);
    return map;
  }

  Future<int> countCreatedGroups() async {
    final uid = _userId;
    if (uid == null) return 0;
    final rows = await _client.from('chat_groups').select('id').eq('created_by', uid);
    return (rows as List).length;
  }

  Future<ChatGroup?> fetchGroup(String groupId) async {
    final uid = _userId;
    if (uid == null) return null;

    final row = await _client
        .from('chat_groups')
        .select(_groupFields)
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) return null;

    final memberRow = await _client
        .from('chat_group_members')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', uid)
        .maybeSingle();

    final map = await _attachAdminCount({
      ...row,
      'is_member': memberRow != null,
      'is_admin': (memberRow?['role'] as String?) == 'admin',
    });
    return ChatGroup.fromJson(map);
  }

  Future<List<GroupMember>> fetchGroupMembers(String groupId) async {
    final rows = await _client
        .from('chat_group_members')
        .select(
          'role, user:users!chat_group_members_user_id_fkey(id, name, username, image)',
        )
        .eq('group_id', groupId)
        .order('role', ascending: true);

    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final user = map['user'] as Map<String, dynamic>;
      return GroupMember(
        userId: user['id'] as String,
        displayName: user['name'] as String? ?? user['username'] as String? ?? 'Usuario',
        username: user['username'] as String?,
        imageUrl: user['image'] as String?,
        role: map['role'] as String,
      );
    }).toList();
  }

  Future<List<ChatGroup>> fetchMyGroups() async {
    final uid = _userId;
    if (uid == null) return [];

    final memberships = await _client
        .from('chat_group_members')
        .select('role, group:chat_groups($_groupFields)')
        .eq('user_id', uid);

    final result = <ChatGroup>[];
    for (final row in memberships as List) {
      final map = row as Map<String, dynamic>;
      final groupMap = map['group'] as Map<String, dynamic>?;
      if (groupMap == null) continue;

      final enriched = await _withLastMessage(await _attachAdminCount({
        ...groupMap,
        'is_member': true,
        'is_admin': map['role'] == 'admin',
      }));
      result.add(ChatGroup.fromJson(enriched));
    }

    result.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return result;
  }

  Future<List<ChatGroup>> fetchAllGroups() async {
    final uid = _userId;
    if (uid == null) return [];

    final memberships = await _client
        .from('chat_group_members')
        .select('group_id, role')
        .eq('user_id', uid);

    final memberRoles = {
      for (final m in memberships as List)
        (m as Map)['group_id'] as String: m['role'] as String,
    };

    final rows = await _client
        .from('chat_groups')
        .select(_groupFields)
        .order('created_at', ascending: false)
        .limit(100);

    final result = <ChatGroup>[];
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String;
      final role = memberRoles[id];
      result.add(ChatGroup.fromJson(await _attachAdminCount({
        ...map,
        'is_member': role != null,
        'is_admin': role == 'admin',
      })));
    }
    return result;
  }

  Future<int> countUnreadInvites() async {
    final uid = _userId;
    if (uid == null) return 0;
    final rows = await _client
        .from('chat_group_invites')
        .select('id')
        .eq('invitee_id', uid)
        .eq('status', 'pending')
        .isFilter('seen_at', null);
    return (rows as List).length;
  }

  Future<void> markInvitesSeen() async {
    await _client.rpc('mark_group_invites_seen');
  }

  Future<List<GroupInvite>> fetchPendingInvites() async {
    final uid = _userId;
    if (uid == null) return [];

    final rows = await _client
        .from('chat_group_invites')
        .select(
          'id, group_id, status, created_at, seen_at, '
          'group:chat_groups(id, name, is_public), '
          'inviter:users!inviter_id(id, email, name, username, image)',
        )
        .eq('invitee_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (rows as List).map((r) => GroupInvite.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<ChatGroup> createGroupWithInvites({
    required String name,
    required bool isPublic,
    required bool adminsOnlyChat,
    required List<String> inviteeIds,
  }) async {
    if (inviteeIds.length < ChatLimits.minInviteesToCreateGroup) {
      throw MinInviteesException();
    }

    final group = await createGroup(name, isPublic: isPublic, adminsOnlyChat: adminsOnlyChat);
    for (final userId in inviteeIds) {
      await inviteUser(group.id, userId);
    }
    return group;
  }

  Future<ChatGroup> createGroup(
    String name, {
    bool isPublic = false,
    bool adminsOnlyChat = false,
  }) async {
    final created = await countCreatedGroups();
    if (created >= ChatLimits.maxGroupsCreatedPerUser) {
      throw GroupLimitException();
    }

    try {
      final row = await _client.rpc('create_chat_group', params: {
        'p_name': name.trim(),
        'p_is_public': isPublic,
        'p_admins_only_chat': adminsOnlyChat,
      });
      return ChatGroup.fromJson({
        ...(row as Map<String, dynamic>),
        'is_member': true,
        'is_admin': true,
        'admin_count': 1,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('group_limit_reached')) throw GroupLimitException();
      if (e.message.contains('invalid_name')) throw InvalidGroupNameException();
      rethrow;
    }
  }

  Future<ChatGroup> setAdminsOnlyChat(String groupId, bool adminsOnly) async {
    try {
      final row = await _client.rpc('set_group_admins_only_chat', params: {
        'p_group_id': groupId,
        'p_admins_only': adminsOnly,
      });
      final group = await fetchGroup(groupId);
      return group ?? ChatGroup.fromJson(row as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      if (e.message.contains('not_admin')) throw NotGroupAdminException();
      rethrow;
    }
  }

  Future<void> setMemberRole(String groupId, String userId, {required bool asAdmin}) async {
    try {
      await _client.rpc('set_group_member_role', params: {
        'p_group_id': groupId,
        'p_user_id': userId,
        'p_role': asAdmin ? 'admin' : 'member',
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('max_admins_reached')) throw MaxAdminsException();
      if (e.message.contains('last_admin')) throw LastAdminException();
      if (e.message.contains('not_admin')) throw NotGroupAdminException();
      rethrow;
    }
  }

  Future<ChatGroup> joinPublicGroup(String groupId) async {
    try {
      final row = await _client.rpc('join_public_group', params: {'p_group_id': groupId});
      return ChatGroup.fromJson({
        ...(row as Map<String, dynamic>),
        'is_member': true,
        'is_admin': false,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('group_full')) throw GroupFullException();
      if (e.message.contains('already_member')) throw AlreadyMemberException();
      if (e.message.contains('group_private')) throw GroupPrivateException();
      rethrow;
    }
  }

  Future<void> inviteUser(String groupId, String userId) async {
    try {
      await _client.rpc('invite_to_group', params: {
        'p_group_id': groupId,
        'p_invitee_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('group_full')) throw GroupFullException();
      if (e.message.contains('already_member')) throw AlreadyMemberException();
      if (e.message.contains('group_is_public')) throw GroupIsPublicException();
      if (e.message.contains('not_admin')) throw NotGroupAdminException();
      rethrow;
    }
  }

  Future<ChatGroup> acceptInvite(GroupInvite invite) async {
    try {
      await _client.rpc('respond_group_invite', params: {
        'p_invite_id': invite.id,
        'p_accept': true,
      });
      final group = await fetchGroup(invite.groupId);
      if (group == null) throw Exception('Grupo no encontrado');
      return group;
    } on PostgrestException catch (e) {
      if (e.message.contains('group_full')) throw GroupFullException();
      rethrow;
    }
  }

  Future<void> rejectInvite(String inviteId) async {
    await _client.rpc('respond_group_invite', params: {
      'p_invite_id': inviteId,
      'p_accept': false,
    });
  }

  Future<List<GroupChatMessage>> fetchGroupThread(String groupId, {int limit = 100}) async {
    if (_userId == null) return [];

    final rows = await _client
        .from('chat_group_messages')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (rows as List).map((r) => GroupChatMessage.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<GroupChatMessage> sendGroupMessage(
    String groupId, {
    String content = '',
    String? mediaUrl,
    String? mediaType,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    final payload = {
      'group_id': groupId,
      'sender_id': uid,
      'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
    };

    try {
      final row = await _client.from('chat_group_messages').insert(payload).select().single();
      return GroupChatMessage.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        throw AdminsOnlyChatException();
      }
      rethrow;
    }
  }

  Future<({String url, String mediaType})> uploadGroupMedia({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String groupId,
  }) async {
    final url = await _storage.uploadBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      subfolder: 'groups/$groupId',
    );
    final mediaType = mimeType.startsWith('image/')
        ? 'image'
        : mimeType.startsWith('audio/')
            ? 'audio'
            : 'file';
    return (url: url, mediaType: mediaType);
  }

  RealtimeChannel subscribeToGroupMessages(String groupId, void Function(GroupChatMessage) onMessage) {
    final uid = _userId!;
    return _client
        .channel('group_messages:$groupId:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_group_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
          callback: (payload) {
            onMessage(GroupChatMessage.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<Map<String, dynamic>> _withLastMessage(Map<String, dynamic> map) async {
    final groupId = map['id'] as String;
    final lastRows = await _client
        .from('chat_group_messages')
        .select('content, created_at, media_type')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(1);

    if (lastRows.isNotEmpty) {
      final last = lastRows.first;
      map['last_message_preview'] = _previewForMessage(last);
      map['last_message_at'] = last['created_at'];
    }
    return map;
  }

  String _previewForMessage(Map<String, dynamic> row) {
    final content = (row['content'] as String?)?.trim() ?? '';
    final mediaType = row['media_type'] as String?;
    if (content.isNotEmpty) return content;
    return switch (mediaType) {
      'image' => '📷 Imagen',
      'audio' => '🎤 Audio',
      'sticker' => '😊 Sticker',
      _ => 'Archivo adjunto',
    };
  }
}

class GroupLimitException implements Exception {
  @override
  String toString() => 'Solo puedes crear ${ChatLimits.maxGroupsCreatedPerUser} grupos.';
}

class InvalidGroupNameException implements Exception {
  @override
  String toString() => 'El nombre del grupo debe tener al menos 2 caracteres.';
}

class GroupFullException implements Exception {
  @override
  String toString() => 'El grupo ya alcanzó el límite de ${ChatLimits.maxMembersPerGroup} miembros.';
}

class AlreadyMemberException implements Exception {
  @override
  String toString() => 'Esta persona ya está en el grupo.';
}

class GroupPrivateException implements Exception {
  @override
  String toString() => 'Este grupo es privado. Necesitas una invitación.';
}

class GroupIsPublicException implements Exception {
  @override
  String toString() => 'Los grupos públicos no usan invitaciones. Comparte el enlace para unirse.';
}

class NotGroupAdminException implements Exception {
  @override
  String toString() => 'Solo los administradores pueden invitar.';
}

class MinInviteesException implements Exception {
  @override
  String toString() =>
      'Selecciona al menos ${ChatLimits.minInviteesToCreateGroup} personas para crear el grupo.';
}

class MaxAdminsException implements Exception {
  @override
  String toString() => 'Solo puede haber ${ChatLimits.maxAdminsPerGroup} administradores.';
}

class LastAdminException implements Exception {
  @override
  String toString() => 'El grupo debe tener al menos un administrador.';
}

class AdminsOnlyChatException implements Exception {
  @override
  String toString() => 'Solo los administradores pueden enviar mensajes en este grupo.';
}
