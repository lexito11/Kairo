import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/chat_group.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../auth/services/auth_service.dart';
import '../../chat/widgets/group_avatar.dart';

String searchPersonSubtitle(KairoUser user) {
  final bio = user.bio?.trim();
  if (bio != null && bio.isNotEmpty) return bio;
  if (user.username != null && user.username!.isNotEmpty) return '@${user.username}';
  return 'Miembro de KAIRO';
}

String? searchPostThumbUrl(Post post) {
  final items = post.mediaItems;
  if (items.isEmpty) return null;
  return items.first.url;
}

Future<bool> ensureSignedIn(BuildContext context) async {
  if (AuthService().isSignedIn) return true;
  if (context.mounted) context.push('/auth/signin');
  return false;
}

class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.icon,
  });

  final IconData? icon;
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: KairoColors.darkText),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: KairoColors.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: KairoColors.primary400,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Ver todo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class SearchFollowButton extends StatelessWidget {
  const SearchFollowButton({
    super.key,
    required this.following,
    required this.loading,
    required this.onPressed,
  });

  final bool following;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary500),
      );
    }
    if (following) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: KairoColors.darkTextSecondary,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: const Text('Siguiendo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Agregar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class SearchPersonRow extends StatelessWidget {
  const SearchPersonRow({
    super.key,
    required this.user,
    required this.following,
    required this.onOpen,
    required this.onToggleFollow,
    this.followLoading = false,
  });

  final KairoUser user;
  final bool following;
  final bool followLoading;
  final VoidCallback onOpen;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpen,
            child: KairoAvatar(imageUrl: user.image, name: user.displayName, size: 48),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      color: KairoColors.darkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    searchPersonSubtitle(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          SearchFollowButton(
            following: following,
            loading: followLoading,
            onPressed: onToggleFollow,
          ),
        ],
      ),
    );
  }
}

class SearchGroupRow extends StatelessWidget {
  const SearchGroupRow({
    super.key,
    required this.group,
    required this.onTap,
  });

  final ChatGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visibility = group.isPublic ? 'Público' : 'Privado';
    final members = group.memberCount == 1 ? '1 miembro' : '${group.memberCount} miembros';
    final description = group.description?.trim();
    final subtitle = (description != null && description.isNotEmpty)
        ? description
        : '$visibility · $members';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            GroupAvatar(imageUrl: group.imageUrl, size: 48, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: KairoColors.darkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchMediaThumb extends StatelessWidget {
  const SearchMediaThumb({
    super.key,
    required this.post,
    this.caption,
    this.onTap,
  });

  final Post post;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = searchPostThumbUrl(post);
    final video = postHasVideo(post);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => const ColoredBox(color: KairoColors.darkCard),
                errorWidget: (_, __, ___) => const ColoredBox(color: KairoColors.darkCard),
              )
            else
              ColoredBox(
                color: KairoColors.darkCard,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      post.content,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: KairoColors.darkText, fontSize: 13, height: 1.3),
                    ),
                  ),
                ),
              ),
            if (url != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
            if (video)
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 42),
              ),
            if (caption != null && caption!.trim().isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  caption!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
