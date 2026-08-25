import 'dart:convert';
import '../utils/media_utils.dart';
import 'kairo_user.dart';

enum PostKind { post, testimony, prayer }

PostKind postKindFromString(String? v) {
  switch (v) {
    case 'testimony':
      return PostKind.testimony;
    case 'prayer':
      return PostKind.prayer;
    default:
      return PostKind.post;
  }
}

String postKindToString(PostKind k) {
  switch (k) {
    case PostKind.testimony:
      return 'testimony';
    case PostKind.prayer:
      return 'prayer';
    case PostKind.post:
      return 'post';
  }
}

class Post implements PostLike {
  const Post({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.author,
    this.mediaUrl,
    this.mediaType,
    this.mediaUrls,
    this.postKind = PostKind.post,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.intercessionsCount = 0,
    this.hasInterceded = false,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final KairoUser author;
  @override
  final String? mediaUrl;
  @override
  final String? mediaType;
  @override
  final List<String>? mediaUrls;
  final PostKind postKind;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final int intercessionsCount;
  final bool hasInterceded;

  bool get isPrayer => postKind == PostKind.prayer;
  bool get isTestimony => postKind == PostKind.testimony;

  /// Un único archivo y es video → permite expansión a pantalla completa en el feed.
  bool get isSoloVideo {
    final list = mediaItems;
    return list.length == 1 && list.first.isVideo;
  }

  static List<String>? _parseMediaUrls(String? mediaUrl) {
    if (mediaUrl == null || mediaUrl.isEmpty) return null;
    try {
      final parsed = jsonDecode(mediaUrl);
      if (parsed is List) return parsed.cast<String>();
    } catch (_) {}
    return [mediaUrl];
  }

  factory Post.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final authorJson = json['author'] as Map<String, dynamic>?;
    final likes = json['likes'] as List?;
    final intercessions = json['intercessions'] as List?;
    final countJson = json['_count'] as Map<String, dynamic>?;

    return Post(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      author: authorJson != null
          ? KairoUser.fromJson(authorJson)
          : KairoUser(id: json['author_id'] as String, email: ''),
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      mediaUrls: _parseMediaUrls(json['media_url'] as String?),
      postKind: postKindFromString(json['post_kind'] as String?),
      likesCount: countJson?['likes'] as int? ?? (likes?.length ?? 0),
      commentsCount: countJson?['comments'] as int? ?? 0,
      isLiked: currentUserId != null &&
          (likes?.any((l) {
            final m = l as Map;
            return m['user_id'] == currentUserId || m['author_id'] == currentUserId;
          }) ?? false),
      intercessionsCount: countJson?['intercessions'] as int? ?? intercessions?.length ?? 0,
      hasInterceded: currentUserId != null &&
          (intercessions?.any((l) => (l as Map)['user_id'] == currentUserId) ?? false),
    );
  }

  Post copyWith({
    String? content,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    int? intercessionsCount,
    bool? hasInterceded,
  }) {
    return Post(
      id: id,
      content: content ?? this.content,
      createdAt: createdAt,
      author: author,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaUrls: mediaUrls,
      postKind: postKind,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      intercessionsCount: intercessionsCount ?? this.intercessionsCount,
      hasInterceded: hasInterceded ?? this.hasInterceded,
    );
  }
}
