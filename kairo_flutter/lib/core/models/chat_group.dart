class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.createdBy,
    required this.memberCount,
    this.isPublic = false,
    this.adminsOnlyChat = false,
    this.isMember = true,
    this.isAdmin = false,
    this.adminCount = 1,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String createdBy;
  final int memberCount;
  final bool isPublic;
  final bool adminsOnlyChat;
  final bool isMember;
  final bool isAdmin;
  final int adminCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  bool get canSendMessages => !adminsOnlyChat || isAdmin;

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String,
      memberCount: json['member_count'] as int? ?? 1,
      isPublic: json['is_public'] as bool? ?? false,
      adminsOnlyChat: json['admins_only_chat'] as bool? ?? false,
      isMember: json['is_member'] as bool? ?? true,
      isAdmin: json['is_admin'] as bool? ?? false,
      adminCount: json['admin_count'] as int? ?? 1,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
    this.imageUrl,
    this.username,
  });

  final String userId;
  final String displayName;
  final String role;
  final String? imageUrl;
  final String? username;

  bool get isAdmin => role == 'admin';
}

class GroupChatMessage {
  const GroupChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.mediaUrl,
    this.mediaType,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? mediaUrl;
  final String? mediaType;

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isImage => mediaType == 'image';
  bool get isAudio => mediaType == 'audio';
  bool get isSticker => mediaType == 'sticker';

  bool isMine(String userId) => senderId == userId;

  factory GroupChatMessage.fromJson(Map<String, dynamic> json) {
    return GroupChatMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }
}
