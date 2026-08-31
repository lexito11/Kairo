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
    required this.thumbnailUrl,
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
  final String thumbnailUrl;
  final List<String> tags;
  final bool isLive;
  final bool isHostSession;

  int get qualifiedTotal => totalViewers ?? viewerCount;

  LiveStream copyWith({
    int? viewerCount,
    int? totalViewers,
    int? likesCount,
    bool? isLive,
  }) {
    return LiveStream(
      id: id,
      host: host,
      title: title,
      orientation: orientation,
      viewerCount: viewerCount ?? this.viewerCount,
      totalViewers: totalViewers ?? this.totalViewers,
      likesCount: likesCount ?? this.likesCount,
      thumbnailUrl: thumbnailUrl,
      tags: tags,
      isLive: isLive ?? this.isLive,
      isHostSession: isHostSession,
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
}

String formatLiveCount(int n) {
  if (n < 1000) return '$n';
  final k = n / 1000;
  if (k >= 10) return '${k.round()}k';
  var s = k.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return '${s}k';
}
