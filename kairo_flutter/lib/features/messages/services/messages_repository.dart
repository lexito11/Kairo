import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/message.dart';

class MessagesRepository {
  MessagesRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<List<Conversation>> fetchConversations() async {
    final uid = _userId;
    if (uid == null) return [];

    final rows = await _client
        .from('messages')
        .select('id, content, created_at, sender_id, receiver_id, read_at, media_url, media_type')
        .or('sender_id.eq.$uid,receiver_id.eq.$uid')
        .order('created_at', ascending: false)
        .limit(200);

    final byOther = <String, ChatMessage>{};
    final unread = <String, int>{};

    for (final row in rows as List) {
      final msg = ChatMessage.fromJson(row as Map<String, dynamic>);
      final otherId = msg.senderId == uid ? msg.receiverId : msg.senderId;
      byOther.putIfAbsent(otherId, () => msg);
      if (msg.receiverId == uid && msg.readAt == null) {
        unread[otherId] = (unread[otherId] ?? 0) + 1;
      }
    }

    if (byOther.isEmpty) return [];

    final users = await _client
        .from('users')
        .select('id, email, name, username, image')
        .inFilter('id', byOther.keys.toList());

    final userMap = {
      for (final u in users as List) (u as Map)['id'] as String: KairoUser.fromJson(u as Map<String, dynamic>),
    };

    return byOther.entries.map((e) {
      return Conversation(
        otherUser: userMap[e.key] ?? KairoUser(id: e.key, email: ''),
        lastMessage: e.value,
        unreadCount: unread[e.key] ?? 0,
      );
    }).toList();
  }

  Future<List<ChatMessage>> fetchThread(String otherUserId) async {
    final uid = _userId;
    if (uid == null) return [];

    final rows = await _client
        .from('messages')
        .select()
        .or('and(sender_id.eq.$uid,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$uid)')
        .order('created_at', ascending: true);

    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('receiver_id', uid)
        .eq('sender_id', otherUserId)
        .isFilter('read_at', null);

    return (rows as List).map((r) => ChatMessage.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage(
    String receiverId,
    String content, {
    String? mediaUrl,
    String? mediaType,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    final row = await _client.from('messages').insert({
      'sender_id': uid,
      'receiver_id': receiverId,
      'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
    }).select().single();

    return ChatMessage.fromJson(row);
  }

  RealtimeChannel subscribeToMessages(void Function(ChatMessage) onMessage) {
    final uid = _userId!;
    return _client
        .channel('messages:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: uid),
          callback: (payload) {
            onMessage(ChatMessage.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }
}
