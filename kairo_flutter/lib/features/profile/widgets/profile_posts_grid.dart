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
    this.saved = false,
    this.emptyText = 'Sin publicaciones',
  });

  final List<Post> posts;
  final ValueChanged<Post> onOpen;
  final String? moodBadge;
  final bool saved;
  final String emptyText;

  static const _gap = 1.5;
  static const _aspect = 3 / 4;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(emptyText, style: const TextStyle(color: KairoColors.darkTextSecondary)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: _gap,
        crossAxisSpacing: _gap,
        childAspectRatio: _aspect,
      ),
      itemBuilder: (context, i) {
        final post = posts[i];
        return _ProfilePostTile(
          post: post,
          onOpen: () => onOpen(post),
          moodBadge: i == 0 ? moodBadge : null,
          saved: saved,
        );
      },
    );
  }
}

class _ProfilePostTile extends StatelessWidget {
  const _ProfilePostTile({
    required this.post,
    required this.onOpen,
    this.moodBadge,
    this.saved = false,
  });

  final Post post;
  final VoidCallback onOpen;
  final String? moodBadge;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final media = post.mediaItems;
    final imageUrl = media.isEmpty
        ? null
        : media.first.isVideo
            ? null
            : media.first.url;
    final isVideo = media.isNotEmpty && media.first.isVideo;

    return GestureDetector(
      onTap: onOpen,
      child: ColoredBox(
        color: KairoColors.darkCard,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _media(imageUrl, isVideo),
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
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    moodBadge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (saved)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.bookmark, color: Colors.white, size: 16),
              ),
            if (isVideo)
              Positioned(
                top: 6,
                right: saved ? 26 : 6,
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: _stat(Icons.favorite, post.likesCount),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _stat(Icons.chat_bubble_outline, post.commentsCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
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
      return ColoredBox(color: KairoColors.darkHover, child: _fallback());
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
              padding: const EdgeInsets.all(8),
              child: Text(
                text,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.25),
              ),
            ),
    );
  }
}






