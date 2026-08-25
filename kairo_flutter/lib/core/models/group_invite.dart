import '../models/kairo_user.dart';

enum GroupInviteStatus { pending, accepted, rejected }

class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviter,
    required this.status,
    required this.createdAt,
    this.isPublic = false,
    this.isUnread = true,
  });

  final String id;
  final String groupId;
  final String groupName;
  final KairoUser inviter;
  final GroupInviteStatus status;
  final DateTime createdAt;
  final bool isPublic;
  final bool isUnread;

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    final group = json['group'] as Map<String, dynamic>?;
    final inviterJson = json['inviter'] as Map<String, dynamic>?;
    final statusRaw = json['status'] as String? ?? 'pending';

    return GroupInvite(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      groupName: group?['name'] as String? ?? 'Grupo',
      isPublic: group?['is_public'] as bool? ?? false,
      isUnread: json['seen_at'] == null,
      inviter: inviterJson != null
          ? KairoUser.fromJson(inviterJson)
          : KairoUser(id: json['inviter_id'] as String, email: ''),
      status: GroupInviteStatus.values.firstWhere(
        (s) => s.name == statusRaw,
        orElse: () => GroupInviteStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
