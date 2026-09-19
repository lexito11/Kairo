import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.infractionId,
  });

  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? infractionId;

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    return ModerationReport(
      id: json['id'].toString(),
      reporterId: json['reporter_id']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      infractionId: json['infraction_id']?.toString(),
    );
  }
}

class ContentInfraction {
  const ContentInfraction({
    required this.id,
    required this.userId,
    required this.contentType,
    required this.contentId,
    required this.category,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.mediaRef,
    this.contentRemoved = true,
    this.detectionMethod,
    this.storageDeleted = false,
  });

  final String id;
  final String userId;
  final String contentType;
  final String contentId;
  final String category;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? mediaRef;
  final bool contentRemoved;
  final String? detectionMethod;
  final bool storageDeleted;

  factory ContentInfraction.fromJson(Map<String, dynamic> json) {
    return ContentInfraction(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      contentId: json['content_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'confirmed',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      mediaRef: json['media_ref']?.toString(),
      contentRemoved: json['content_removed'] != false,
      detectionMethod: json['detection_method']?.toString(),
      storageDeleted: json['storage_deleted'] == true,
    );
  }
}

class BlockedAccountRow {
  const BlockedAccountRow({
    required this.userId,
    required this.email,
    this.name,
    this.username,
    this.blockedAt,
    this.blockedReason,
    this.infractionCount = 0,
  });

  final String userId;
  final String email;
  final String? name;
  final String? username;
  final DateTime? blockedAt;
  final String? blockedReason;
  final int infractionCount;

  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final u = username?.trim();
    if (u != null && u.isNotEmpty) return '@$u';
    if (email.isNotEmpty) return email;
    return userId;
  }

  factory BlockedAccountRow.fromJson(Map<String, dynamic> json) {
    return BlockedAccountRow(
      userId: json['id'].toString(),
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      username: json['username'] as String?,
      blockedAt: json['blocked_at'] == null
          ? null
          : DateTime.tryParse(json['blocked_at'].toString()),
      blockedReason: json['blocked_reason'] as String?,
      infractionCount: json['infraction_count'] is int
          ? json['infraction_count'] as int
          : int.tryParse('${json['infraction_count'] ?? 0}') ?? 0,
    );
  }
}

class ModerationQueueItem {
  const ModerationQueueItem({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.status,
    required this.createdAt,
    this.userId,
    this.mediaRef,
    this.mediaType,
    this.category,
    this.reason,
    this.analysisNotes,
    this.lastError,
    this.attempts = 0,
  });

  final String id;
  final String contentType;
  final String contentId;
  final String status;
  final DateTime createdAt;
  final String? userId;
  final String? mediaRef;
  final String? mediaType;
  final String? category;
  final String? reason;
  final String? analysisNotes;
  final String? lastError;
  final int attempts;

  factory ModerationQueueItem.fromJson(Map<String, dynamic> json) {
    return ModerationQueueItem(
      id: json['id'].toString(),
      contentType: json['content_type']?.toString() ?? '',
      contentId: json['content_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      userId: json['user_id']?.toString(),
      mediaRef: json['media_ref']?.toString(),
      mediaType: json['media_type']?.toString(),
      category: json['category']?.toString(),
      reason: json['reason']?.toString(),
      analysisNotes: json['analysis_notes']?.toString(),
      lastError: json['last_error']?.toString(),
      attempts: json['attempts'] is int
          ? json['attempts'] as int
          : int.tryParse('${json['attempts'] ?? 0}') ?? 0,
    );
  }
}

class InfractionConfirmResult {
  const InfractionConfirmResult({
    required this.infractionId,
    required this.userId,
    required this.infractionCount,
    required this.accountBlocked,
    required this.duplicate,
  });

  final String? infractionId;
  final String? userId;
  final int infractionCount;
  final bool accountBlocked;
  final bool duplicate;
}

class ModerationRepository {
  ModerationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ModerationReport>> fetchPendingReports() async {
    final rows = await _client
        .from('content_reports')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => ModerationReport.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<BlockedAccountRow>> fetchBlockedAccounts() async {
    final rows = await _client
        .from('users')
        .select('id, email, name, username, blocked_at, blocked_reason, infraction_count')
        .eq('account_status', 'blocked')
        .order('blocked_at', ascending: false);
    return (rows as List)
        .map((r) => BlockedAccountRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<ContentInfraction>> fetchUserInfractions(String userId) async {
    final rows = await _client
        .from('content_infractions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => ContentInfraction.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<ModerationQueueItem>> fetchQueue() async {
    final rows = await _client
        .from('moderation_queue')
        .select()
        .inFilter('status', ['pending', 'processing', 'flagged'])
        .order('created_at', ascending: false)
        .limit(80);
    return (rows as List)
        .map((r) => ModerationQueueItem.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<InfractionConfirmResult> reviewQueueItem(String queueId, {required String action}) async {
    final raw = await _client.rpc(
      'review_moderation_queue_item',
      params: {
        'p_queue_id': queueId,
        'p_action': action,
      },
    );
    return _mapResult(raw);
  }

  Future<InfractionConfirmResult> reviewReport(String reportId, {required bool confirm}) async {
    final raw = await _client.rpc(
      'review_content_report',
      params: {
        'p_report_id': reportId,
        'p_action': confirm ? 'confirm' : 'dismiss',
      },
    );
    return _mapResult(raw);
  }

  Future<void> flushAdminEmails() async {
    try {
      await _client.rpc('flush_admin_block_emails');
    } on PostgrestException {
      // Optional retry path if pg_net was unavailable at block time.
    }
  }

  InfractionConfirmResult _mapResult(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return InfractionConfirmResult(
      infractionId: map['infraction_id']?.toString(),
      userId: map['user_id']?.toString(),
      infractionCount: map['infraction_count'] is int
          ? map['infraction_count'] as int
          : int.tryParse('${map['infraction_count'] ?? 0}') ?? 0,
      accountBlocked: map['account_blocked'] == true,
      duplicate: map['duplicate'] == true,
    );
  }
}
