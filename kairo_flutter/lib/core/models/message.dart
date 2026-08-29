import 'kairo_user.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.senderId,
    required this.receiverId,
    this.readAt,
    this.mediaUrl,
    this.mediaType,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final String senderId;
  final String receiverId;
  final DateTime? readAt;
  final String? mediaUrl;
  final String? mediaType;

  bool isMine(String userId) => senderId == userId;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isImage => mediaType == 'image' || (mediaType == null && hasMedia);
  bool get isVideo => mediaType == 'video';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }
}

class Conversation {
  const Conversation({
    required this.otherUser,
    required this.lastMessage,
    required this.unreadCount,
  });

  final KairoUser otherUser;
  final ChatMessage lastMessage;
  final int unreadCount;

  Conversation copyWith({
    ChatMessage? lastMessage,
    int? unreadCount,
  }) {
    return Conversation(
      otherUser: otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
