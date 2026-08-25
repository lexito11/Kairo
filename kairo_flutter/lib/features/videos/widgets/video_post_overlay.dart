import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/post.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../posts/services/posts_repository.dart';
import '../../posts/widgets/amen_likers_sheet.dart';

class VideoPostOverlay extends StatefulWidget {
  const VideoPostOverlay({
    super.key,
    required this.post,
    required this.isOwner,
    required this.isFollowingAuthor,
    required this.followLoading,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onToggleFollow,
    this.onMenuSelected,
  });

  final Post post;
  final bool isOwner;
  final bool isFollowingAuthor;
  final bool followLoading;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onToggleFollow;
  final void Function(String)? onMenuSelected;

  @override
  State<VideoPostOverlay> createState() => _VideoPostOverlayState();
}

class _VideoPostOverlayState extends State<VideoPostOverlay> {
  final _prefs = PrefsService();
  bool _saved = false;
  bool _expanded = false;

  static const _textShadow = [
    Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 1)),
    Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void didUpdateWidget(covariant VideoPostOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _expanded = false;
      _loadSaved();
    }
  }

  Future<void> _loadSaved() async {
    final saved = await _prefs.isPostSaved(widget.post.id);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _toggleSaved() async {
    final saved = await _prefs.toggleSavedPost(widget.post.id);
    if (mounted) setState(() => _saved = saved);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final showFollow = widget.onToggleFollow != null && !widget.isOwner;
    const charLimit = 120;
    final shouldTruncate = post.content.length > charLimit;
    final body = shouldTruncate && !_expanded
        ? '${post.content.substring(0, charLimit)}...'
        : post.content;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 16,
          right: 88,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: () => context.push('/profile?userId=${post.author.id}'),
                      child: Text(
                        post.author.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          shadows: _textShadow,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  if (showFollow) ...[
                    const SizedBox(width: 8),
                    _FollowLink(
                      isFollowing: widget.isFollowingAuthor,
                      loading: widget.followLoading,
                      onPressed: widget.onToggleFollow!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatTimeAgo(post.createdAt),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  shadows: _textShadow,
                ),
              ),
              if (post.likesCount > 0) ...[
                const SizedBox(height: 8),
                _VideoAmenLikesLine(
                  key: ValueKey('${post.id}_${post.likesCount}'),
                  postId: post.id,
                  likesCount: post.likesCount,
                ),
              ],
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.3,
                    shadows: _textShadow,
                  ),
                ),
                if (shouldTruncate)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _expanded ? 'Ver menos' : 'Ver más',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          shadows: _textShadow,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 10,
          bottom: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VideoActionButton(
                icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                label: '${post.likesCount} Amén',
                iconColor: post.isLiked ? Colors.red : Colors.white,
                onTap: widget.onLike,
              ),
              const SizedBox(height: 14),
              _VideoActionButton(
                icon: Icons.chat_bubble_outline,
                label: '${post.commentsCount} Comentar',
                onTap: widget.onComment,
              ),
              const SizedBox(height: 14),
              _VideoActionButton(
                icon: Icons.share_outlined,
                label: '0 Compartir',
                onTap: widget.onShare,
              ),
              const SizedBox(height: 14),
              _VideoActionButton(
                icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                label: _saved ? 'Guardado' : 'Guardar',
                onTap: _toggleSaved,
              ),
              if (widget.isOwner && widget.onMenuSelected != null) ...[
                const SizedBox(height: 14),
                _VideoActionButton(
                  icon: Icons.more_vert,
                  label: 'Más',
                  onTap: () => _showOwnerMenu(context),
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.push('/profile?userId=${post.author.id}'),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: KairoAvatar(
                    imageUrl: post.author.image,
                    name: post.author.displayName,
                    size: 44,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOwnerMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KairoColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: KairoColors.darkText),
              title: const Text('Editar texto', style: TextStyle(color: KairoColors.darkText)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onMenuSelected?.call('edit');
              },
            ),
            if (widget.post.content.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.text_fields_outlined, color: KairoColors.errorText),
                title: const Text('Eliminar texto', style: TextStyle(color: KairoColors.errorText)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onMenuSelected?.call('delete_text');
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: KairoColors.errorText),
              title: const Text('Eliminar publicación', style: TextStyle(color: KairoColors.errorText)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onMenuSelected?.call('delete_post');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowLink extends StatelessWidget {
  const _FollowLink({
    required this.isFollowing,
    required this.loading,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: KairoColors.primary400,
        overlayColor: Colors.transparent,
      ),
      child: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary400),
            )
          : Text(
              isFollowing ? 'Dejar de seguir' : 'Seguir',
              style: const TextStyle(
                color: KairoColors.primary400,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: _VideoPostOverlayState._textShadow,
              ),
            ),
    );
  }
}

class _VideoActionButton extends StatelessWidget {
  const _VideoActionButton({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: _VideoPostOverlayState._textShadow,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VideoAmenLikesLine extends StatefulWidget {
  const _VideoAmenLikesLine({
    super.key,
    required this.postId,
    required this.likesCount,
  });

  final String postId;
  final int likesCount;

  @override
  State<_VideoAmenLikesLine> createState() => _VideoAmenLikesLineState();
}

class _VideoAmenLikesLineState extends State<_VideoAmenLikesLine> {
  final _repo = PostsRepository();
  KairoUser? _featured;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoAmenLikesLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId || oldWidget.likesCount != widget.likesCount) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await _repo.fetchPostLikersSummary(widget.postId);
      if (mounted) setState(() { _featured = summary.featured; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _featured == null) return const SizedBox.shrink();

    final featuredName = amenLikerPublicName(_featured!);
    const metaStyle = TextStyle(color: Colors.white70, fontSize: 12, height: 1.3, shadows: _VideoPostOverlayState._textShadow);
    const boldStyle = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.3, shadows: _VideoPostOverlayState._textShadow);
    const todosStyle = TextStyle(color: KairoColors.primary400, fontSize: 12, fontWeight: FontWeight.bold, height: 1.3, shadows: _VideoPostOverlayState._textShadow);

    return GestureDetector(
      onTap: () => showAmenLikersSheet(context, widget.postId),
      behavior: HitTestBehavior.opaque,
      child: Text.rich(
        TextSpan(
          style: metaStyle,
          children: [
            const TextSpan(text: 'Les gusta a '),
            TextSpan(text: '$featuredName ', style: boldStyle),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => showAmenLikersSheet(context, widget.postId),
                child: const Text('todos', style: todosStyle),
              ),
            ),
            if (widget.likesCount > 1) const TextSpan(text: ' y otros', style: boldStyle),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
