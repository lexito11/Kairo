import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/inline_video_player.dart';
import '../../../core/widgets/kairo_avatar.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onIntercede,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onIntercede;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasInterceded = post.hasInterceded;
    final intercessions = post.intercessionsCount;
    final items = post.mediaItems;
    final hasMedia = items.isNotEmpty;
    final charLimit = hasMedia ? 150 : 300;
    final shouldTruncate = post.content.length > charLimit;
    final displayContent = shouldTruncate && !_expanded
        ? '${post.content.substring(0, charLimit)}...'
        : post.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KairoColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isPrayer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Row(
                children: [
                  Text('🙏', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text('Petición de oración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          if (post.isTestimony)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: KairoColors.buttonGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Row(
                children: [
                  Text('✨', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text('Testimonio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KairoAvatar(
                      imageUrl: post.isAnonymous ? null : post.author.image,
                      name: post.isAnonymous ? '?' : post.author.displayName,
                      size: 44,
                      onTap: post.isAnonymous
                          ? null
                          : () => context.push('/profile?userId=${post.author.id}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: post.isAnonymous
                            ? null
                            : () => context.push('/profile?userId=${post.author.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.isAnonymous ? 'Anónimo' : post.author.displayName,
                              style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            Text(
                              formatTimeAgo(post.createdAt),
                              style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (post.content.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(displayContent, style: const TextStyle(color: KairoColors.darkText, fontSize: 15, height: 1.4)),
                  if (shouldTruncate)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _expanded ? 'Ver menos' : 'Ver más',
                          style: const TextStyle(color: KairoColors.primary400, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                ],
                if (hasMedia) ...[
                  const SizedBox(height: 12),
                  _MediaPreview(items: items),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ActionButton(
                      icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                      label: _formatCount(post.likesCount),
                      color: post.isLiked ? Colors.red : KairoColors.darkTextSecondary,
                      onTap: widget.onLike,
                    ),
                    const SizedBox(width: 20),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: _formatCount(post.commentsCount),
                      onTap: widget.onComment,
                    ),
                    const SizedBox(width: 20),
                    _ActionButton(icon: Icons.share_outlined, label: 'Compartir', onTap: widget.onShare),
                    if (post.isPrayer) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: hasInterceded ? null : widget.onIntercede,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasInterceded ? KairoColors.primary500.withValues(alpha: 0.2) : KairoColors.darkHover,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: hasInterceded ? KairoColors.primary500 : KairoColors.darkBorder),
                          ),
                          child: Text(
                            hasInterceded ? '🙏 Intercediste' : '🙏 Interceder${intercessions > 0 ? ' ($intercessions)' : ''}',
                            style: TextStyle(
                              color: hasInterceded ? KairoColors.primary400 : KairoColors.darkTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n > 0 ? '$n' : '';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.color, this.onTap});
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? KairoColors.darkTextSecondary),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color ?? KairoColors.darkTextSecondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.items});
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      final item = items.first;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: item.isVideo
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InlineVideoPlayer(url: item.url, height: 280),
              )
            : CachedNetworkImage(
                imageUrl: item.url,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 160,
              child: item.isVideo
                  ? InlineVideoPlayer(url: item.url, height: 200)
                  : CachedNetworkImage(imageUrl: item.url, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}
