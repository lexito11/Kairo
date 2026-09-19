import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/live_stream.dart';
import '../../../core/moderation/kairo_content_policy.dart';

class LiveRepository {
  LiveRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _hostSelect =
      'id, host_id, title, orientation, tags, thumbnail_url, viewer_count, total_viewers, likes_count, is_live, created_at, host:users!host_id(id, email, name, username, image)';
  static const _messageSelect =
      'id, content, kind, created_at, author:users!author_id(id, email, name, username, image)';

  String? get _uid => _client.auth.currentUser?.id;

  String mapError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('live_streams') && (raw.contains('does not exist') || raw.contains('42p01'))) {
      return 'Falta ejecutar la migración de En Vivo en Supabase (025_live_rooms.sql).';
    }
    if (raw.contains('live_join_stream') || raw.contains('live_sweep_stale')) {
      return 'Falta ejecutar la migración de En Vivo en Supabase (025_live_rooms.sql).';
    }
    if (raw.contains('ya no está en vivo') || raw.contains('no está en vivo')) {
      return 'Esta transmisión ya no está en vivo.';
    }
    if (raw.contains('failed to fetch') || raw.contains('socketexception') || raw.contains('network')) {
      return 'No se pudo conectar. Revisa tu internet.';
    }
    return 'No se pudo completar la acción. Inténtalo de nuevo.';
  }

  Future<void> sweepStale() async {
    try {
      await _client.rpc('live_sweep_stale');
    } catch (_) {}
  }

  Future<List<LiveStream>> fetchLiveStreams() async {
    await sweepStale();
    final rows = await _client
        .from('live_streams')
        .select(_hostSelect)
        .eq('is_live', true)
        .order('viewer_count', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => LiveStream.fromJson(Map<String, dynamic>.from(r as Map), currentUserId: _uid))
        .toList();
  }

  Future<LiveStream?> fetchById(String id) async {
    final row = await _client.from('live_streams').select(_hostSelect).eq('id', id).maybeSingle();
    if (row == null) return null;
    return LiveStream.fromJson(row, currentUserId: _uid);
  }

  Future<LiveStream?> fetchMyLive() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client
        .from('live_streams')
        .select(_hostSelect)
        .eq('host_id', uid)
        .eq('is_live', true)
        .maybeSingle();
    if (row == null) return null;
    return LiveStream.fromJson(row, currentUserId: uid);
  }

  Future<LiveStream> startLive({
    required String title,
    String orientation = '16:9',
    String? thumbnailUrl,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Debes iniciar sesión para ir en vivo');

    final existing = await fetchMyLive();
    if (existing != null) return existing;

    final trimmed = title.trim().isEmpty ? 'Transmisión en vivo' : title.trim();
    KairoContentPolicy.assertText(trimmed);
    final row = await _client.from('live_streams').insert({
      'host_id': uid,
      'title': trimmed,
      'orientation': orientation,
      'thumbnail_url': thumbnailUrl,
      'viewer_count': 0,
      'total_viewers': 0,
      'last_heartbeat': DateTime.now().toUtc().toIso8601String(),
    }).select(_hostSelect).single();
    return LiveStream.fromJson(row, currentUserId: uid);
  }

  Future<void> endLive(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('live_streams').update({
      'is_live': false,
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'viewer_count': 0,
    }).eq('id', id).eq('host_id', uid);
  }

  Future<void> heartbeat(String id) async {
    try {
      await _client.rpc('live_heartbeat', params: {'p_stream_id': id});
    } catch (_) {}
  }

  Future<List<LiveChatMessage>> fetchMessages(String streamId) async {
    final rows = await _client
        .from('live_stream_messages')
        .select(_messageSelect)
        .eq('stream_id', streamId)
        .order('created_at', ascending: true)
        .limit(200);
    return (rows as List)
        .map((r) => LiveChatMessage.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<LiveChatMessage> sendMessage(String streamId, String content, {bool join = false}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Debes iniciar sesión para comentar');
    final text = content.trim();
    if (text.isEmpty) throw Exception('Escribe un mensaje');
    KairoContentPolicy.assertText(text);
    final row = await _client.from('live_stream_messages').insert({
      'stream_id': streamId,
      'author_id': uid,
      'content': text,
      'kind': join ? 'join' : 'chat',
    }).select(_messageSelect).single();
    return LiveChatMessage.fromJson(row);
  }

  Future<bool> isLiked(String streamId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _client
        .from('live_stream_likes')
        .select('user_id')
        .eq('stream_id', streamId)
        .eq('user_id', uid)
        .maybeSingle();
    return row != null;
  }

  Future<bool> toggleLike(String streamId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Debes iniciar sesión para dar me gusta');
    final liked = await isLiked(streamId);
    if (liked) {
      await _client.from('live_stream_likes').delete().eq('stream_id', streamId).eq('user_id', uid);
      return false;
    }
    await _client.from('live_stream_likes').insert({
      'stream_id': streamId,
      'user_id': uid,
    });
    return true;
  }

  String newSessionKey() => const Uuid().v4();

  Future<void> joinStream(String streamId, String sessionKey) {
    return _client.rpc('live_join_stream', params: {
      'p_stream_id': streamId,
      'p_session_key': sessionKey,
    });
  }

  Future<void> qualifyViewer(String streamId, String sessionKey) {
    return _client.rpc('live_qualify_viewer', params: {
      'p_stream_id': streamId,
      'p_session_key': sessionKey,
    });
  }

  Future<void> leaveStream(String streamId, String sessionKey) async {
    try {
      await _client.rpc('live_leave_stream', params: {
        'p_stream_id': streamId,
        'p_session_key': sessionKey,
      });
    } catch (_) {}
  }

  RealtimeChannel subscribeFeed(void Function() onChange) {
    return _client
        .channel('live_streams_feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_streams',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeStream(String streamId, void Function(Map<String, dynamic> row) onUpdate) {
    return _client
        .channel('live_stream:$streamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_streams',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: streamId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  RealtimeChannel subscribeMessages(String streamId, void Function(LiveChatMessage message) onInsert) {
    return _client
        .channel('live_chat:$streamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_stream_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: streamId,
          ),
          callback: (payload) async {
            final id = payload.newRecord['id']?.toString();
            if (id == null) return;
            try {
              final row = await _client
                  .from('live_stream_messages')
                  .select(_messageSelect)
                  .eq('id', id)
                  .maybeSingle();
              if (row != null) onInsert(LiveChatMessage.fromJson(row));
            } catch (_) {}
          },
        )
        .subscribe();
  }
}
