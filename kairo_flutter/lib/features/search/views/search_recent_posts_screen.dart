import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../posts/services/posts_repository.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../services/search_repository.dart';
import '../widgets/search_shared.dart';

class SearchRecentPostsScreen extends StatefulWidget {
  const SearchRecentPostsScreen({super.key});

  @override
  State<SearchRecentPostsScreen> createState() => _SearchRecentPostsScreenState();
}

class _SearchRecentPostsScreenState extends State<SearchRecentPostsScreen> {
  final _search = SearchRepository();
  final _posts = PostsRepository();
  List<Post> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await _search.fetchRecentPosts();
      if (!mounted) return;
      setState(() {
        _items = posts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike(Post post) async {
    if (!await ensureSignedIn(context)) return;
    final idx = _items.indexWhere((p) => p.id == post.id);
    if (idx == -1) return;
    setState(() {
      _items[idx] = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
    });
    try {
      final liked = await _posts.toggleLike(post.id);
      if (!mounted) return;
      setState(() {
        _items[idx] = post.copyWith(
          isLiked: liked,
          likesCount: liked ? post.likesCount + (post.isLiked ? 0 : 1) : post.likesCount - (post.isLiked ? 1 : 0),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _items[idx] = post);
    }
  }

  void _openComments(Post post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: post.id,
        onCommentAdded: () {
          final idx = _items.indexWhere((p) => p.id == post.id);
          if (idx == -1 || !mounted) return;
          setState(() {
            _items[idx] = _items[idx].copyWith(commentsCount: _items[idx].commentsCount + 1);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('Publicaciones recientes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no hay publicaciones',
                    style: TextStyle(color: KairoColors.darkTextSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: KairoColors.darkBorder),
                  itemBuilder: (context, index) {
                    final post = _items[index];
                    return _FeedCard(
                      post: post,
                      onLike: () => _toggleLike(post),
                      onComment: () => _openComments(post),
                    );
                  },
                ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.post,
    required this.onLike,
    required this.onComment,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final thumb = searchPostThumbUrl(post);
    final video = postHasVideo(post);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              KairoAvatar(
                imageUrl: post.author.image,
                name: post.author.displayName,
                size: 40,
                onTap: () => context.push('/profile?userId=${post.author.id}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile?userId=${post.author.id}'),
                      child: Text(
                        post.author.displayName,
                        style: const TextStyle(
                          color: KairoColors.darkText,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      formatTimeAgo(post.createdAt),
                      style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (post.content.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              post.content,
              style: const TextStyle(color: KairoColors.darkText, fontSize: 15, height: 1.35),
            ),
          ),
        if (thumb != null)
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  fadeInDuration: Duration.zero,
                  placeholder: (_, __) => const ColoredBox(color: KairoColors.darkCard),
                  errorWidget: (_, __, ___) => const ColoredBox(color: KairoColors.darkCard),
                ),
                if (video)
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: post.isLiked ? const Color(0xFFF43F5E) : KairoColors.darkText,
                  size: 22,
                ),
                label: Text(
                  '${post.likesCount}',
                  style: const TextStyle(color: KairoColors.darkText),
                ),
              ),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: KairoColors.darkText, size: 20),
                label: Text(
                  '${post.commentsCount}',
                  style: const TextStyle(color: KairoColors.darkText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
