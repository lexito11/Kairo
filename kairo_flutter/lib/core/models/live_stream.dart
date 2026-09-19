import '../models/kairo_user.dart';

class LiveStream {
  const LiveStream({
    required this.id,
    required this.host,
    required this.title,
    required this.orientation,
    required this.viewerCount,
    this.totalViewers,
    required this.likesCount,
    this.thumbnailUrl,
    this.tags = const [],
    this.isLive = true,
    this.isHostSession = false,
  });

  final String id;
  final KairoUser host;
  final String title;
  final String orientation;
  final int viewerCount;
  final int? totalViewers;
  final int likesCount;
  final String? thumbnailUrl;
  final List<String> tags;
  final bool isLive;
  final bool isHostSession;

  String? get displayImage =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ? thumbnailUrl : host.image;

  int get qualifiedTotal => totalViewers ?? viewerCount;

  LiveStream copyWith({
    KairoUser? host,
    String? title,
    int? viewerCount,
    int? totalViewers,
    int? likesCount,
    String? thumbnailUrl,
    bool? isLive,
    bool? isHostSession,
  }) {
    return LiveStream(
      id: id,
      host: host ?? this.host,
      title: title ?? this.title,
      orientation: orientation,
      viewerCount: viewerCount ?? this.viewerCount,
      totalViewers: totalViewers ?? this.totalViewers,
      likesCount: likesCount ?? this.likesCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      tags: tags,
      isLive: isLive ?? this.isLive,
      isHostSession: isHostSession ?? this.isHostSession,
    );
  }

  factory LiveStream.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final hostRaw = json['host'];
    final host = hostRaw is Map
        ? KairoUser.fromJson(Map<String, dynamic>.from(hostRaw))
        : KairoUser(id: '${json['host_id'] ?? ''}', email: '');
    final tagsRaw = json['tags'];
    return LiveStream(
      id: json['id'].toString(),
      host: host,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Transmisión en vivo',
      orientation: json['orientation'] as String? ?? '16:9',
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      totalViewers: (json['total_viewers'] as num?)?.toInt(),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
      tags: tagsRaw is List ? tagsRaw.map((e) => e.toString()).toList() : const [],
      isLive: json['is_live'] as bool? ?? true,
      isHostSession: currentUserId != null && currentUserId == json['host_id']?.toString(),
    );
  }
}

class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.authorName,
    this.authorImage,
    required this.content,
    this.isJoin = false,
  });

  final String id;
  final String authorName;
  final String? authorImage;
  final String content;
  final bool isJoin;

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    final authorRaw = json['author'];
    final author = authorRaw is Map
        ? KairoUser.fromJson(Map<String, dynamic>.from(authorRaw))
        : null;
    final kind = json['kind'] as String? ?? 'chat';
    return LiveChatMessage(
      id: json['id'].toString(),
      authorName: author?.displayName ?? 'Usuario',
      authorImage: author?.image,
      content: json['content'] as String? ?? '',
      isJoin: kind == 'join',
    );
  }
}

String formatLiveCount(int n) {
  if (n < 1000) return '$n';
  final k = n / 1000;
  if (k >= 10) return '${k.round()}k';
  var s = k.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return '${s}k';
}
