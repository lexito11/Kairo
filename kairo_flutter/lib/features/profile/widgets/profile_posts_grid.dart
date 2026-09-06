import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/media_utils.dart';

class ProfilePostsGrid extends StatelessWidget {
  const ProfilePostsGrid({
    super.key,
    required this.posts,
    required this.onOpen,
    this.moodBadge,
  });

  final List<Post> posts;
  final ValueChanged<Post> onOpen;
  final String? moodBadge;

  static const _gap = 8.0;
  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Sin publicaciones', style: TextStyle(color: KairoColors.darkTextSecondary)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - _gap * 2) / 3;
        final tiles = <Widget>[];
        var i = 0;

        if (posts.length == 1) {
          tiles.add(SizedBox(
            height: cell,
            width: double.infinity,
            child: _tile(posts[0], featured: true),
          ));
          i = 1;
        } else if (posts.length >= 2) {
          tiles.add(Row(
            children: [
              Expanded(
                child: SizedBox(height: cell, child: _tile(posts[0], featured: true)),
              ),
              const SizedBox(width: _gap),
              SizedBox(
                width: cell,
                height: cell,
                child: _tile(posts[1]),
              ),
            ],
          ));
          i = 2;
        }

        while (i < posts.length) {
          final row = posts.skip(i).take(3).toList();
          tiles.add(const SizedBox(height: _gap));
          tiles.add(Row(
            children: [
              for (var j = 0; j < 3; j++) ...[
                if (j > 0) const SizedBox(width: _gap),
                Expanded(
                  child: j < row.length
                      ? SizedBox(height: cell, child: _tile(row[j]))
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ));
          i += 3;
        }

        return Column(children: tiles);
      },
    );
  }

  Widget _tile(Post post, {bool featured = false}) {
    return _ProfilePostTile(
      post: post,
      featured: featured,
      moodBadge: featured ? moodBadge : null,
      radius: _radius,
      onOpen: () => onOpen(post),
    );
  }
}

class _ProfilePostTile extends StatelessWidget {
  const _ProfilePostTile({
    required this.post,
    required this.featured,
    required this.radius,
    required this.onOpen,
    this.moodBadge,
  });

  final Post post;
  final bool featured;
  final double radius;
  final VoidCallback onOpen;
  final String? moodBadge;

  @override
  Widget build(BuildContext context) {
    final media = post.mediaItems;
    final imageUrl = media.isEmpty
        ? null
        : media.first.isVideo
            ? null
            : media.first.url;
    final isVideo = media.isNotEmpty && media.first.isVideo;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: GestureDetector(
        onTap: onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: KairoColors.darkCard, child: _media(imageUrl, isVideo)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Color(0x99000000), Color(0x00000000)],
                ),
              ),
            ),
            if (moodBadge != null && moodBadge!.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    moodBadge!,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: _stat(Icons.favorite, post.likesCount),
            ),
            if (featured)
              Positioned(
                right: 8,
                bottom: 8,
                child: _stat(Icons.chat_bubble_outline, post.commentsCount),
              ),
          ],
        ),
      ),
    );
  }

  Widget _media(String? imageUrl, bool isVideo) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (kIsWeb) {
        return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback());
      }
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: KairoColors.darkHover),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    if (isVideo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _fallback(),
          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36)),
        ],
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final text = post.content.trim();
    return ColoredBox(
      color: post.isPrayer
          ? const Color(0xFF3B0764)
          : post.isTestimony
              ? const Color(0xFF0C4A6E)
              : KairoColors.darkHover,
      child: text.isEmpty
          ? const SizedBox.expand()
          : Padding(
              padding: const EdgeInsets.fromLTRB(10, 28, 10, 28),
              child: Text(
                text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
              ),
            ),
    );
  }

  Widget _stat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
