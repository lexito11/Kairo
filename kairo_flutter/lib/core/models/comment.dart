import 'kairo_user.dart';

class Comment {
  const Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.author,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final KairoUser author;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      author: KairoUser.fromJson(json['author'] as Map<String, dynamic>),
    );
  }
}
