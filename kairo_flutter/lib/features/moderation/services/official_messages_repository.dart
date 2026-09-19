import 'package:supabase_flutter/supabase_flutter.dart';

class KairoOfficialMessage {
  const KairoOfficialMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    this.infractionId,
    this.readAt,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String? infractionId;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory KairoOfficialMessage.fromJson(Map<String, dynamic> json) {
    return KairoOfficialMessage(
      id: json['id'].toString(),
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      infractionId: json['infraction_id']?.toString(),
      readAt: json['read_at'] == null
          ? null
          : DateTime.tryParse(json['read_at'].toString()),
    );
  }
}

class OfficialMessagesRepository {
  OfficialMessagesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<List<KairoOfficialMessage>> fetchMine() async {
    final uid = _userId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('kairo_official_messages')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);
      return (rows as List)
          .map((r) => KairoOfficialMessage.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<KairoOfficialMessage?> fetchLatest() async {
    final list = await fetchMine();
    if (list.isEmpty) return null;
    return list.last;
  }

  Future<int> unreadCount() async {
    final uid = _userId;
    if (uid == null) return 0;
    try {
      final rows = await _client
          .from('kairo_official_messages')
          .select('id')
          .eq('user_id', uid)
          .isFilter('read_at', null);
      return (rows as List).length;
    } on PostgrestException {
      return 0;
    }
  }

  Future<void> markAllRead() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await _client
          .from('kairo_official_messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .isFilter('read_at', null);
    } on PostgrestException {
      // Column or table may not exist yet.
    }
  }
}
