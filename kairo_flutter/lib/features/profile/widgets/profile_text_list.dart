import 'package:flutter/material.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../../posts/widgets/post_card.dart';

class ProfileTextList extends StatelessWidget {
  const ProfileTextList({
    super.key,
    required this.posts,
    required this.onEditContent,
    required this.onDeleteText,
    required this.onDeletePost,
  });

  final List<Post> posts;
  final Future<void> Function(String postId, String content) onEditContent;
  final Future<void> Function(String postId) onDeleteText;
  final Future<void> Function(String postId) onDeletePost;

  void _openComments(BuildContext context, String postId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Sin textos',
            style: TextStyle(color: KairoColors.darkTextSecondary),
          ),
        ),
      );
    }

    final uid = AuthService().currentUser?.id;
    return Column(
      children: [
        for (var i = 0; i < posts.length; i++) ...[
          PostCard(
            post: posts[i],
            feedLayout: true,
            isOwner: uid != null && posts[i].author.id == uid,
            onComment: () => _openComments(context, posts[i].id),
            onEditContent: (content) => onEditContent(posts[i].id, content),
            onDeleteText: () => onDeleteText(posts[i].id),
            onDeletePost: () => onDeletePost(posts[i].id),
          ),
          Divider(
            height: 16,
            thickness: 8,
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ],
      ],
    );
  }
}
