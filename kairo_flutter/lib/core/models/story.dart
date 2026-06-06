import 'kairo_user.dart';

class Story {
  const Story({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
    required this.author,
  });

  final String id;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;
  final KairoUser author;

  bool get isVideo => mediaType == 'video';

  factory Story.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'] as Map<String, dynamic>?;
    return Story(
      id: json['id'] as String,
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      author: authorJson != null
          ? KairoUser.fromJson(authorJson)
          : KairoUser(id: json['author_id'] as String, email: ''),
    );
  }
}

class StoryGroup {
  const StoryGroup({required this.author, required this.stories});
  final KairoUser author;
  final List<Story> stories;
}
