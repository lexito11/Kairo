import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/feed_video_visibility.dart';
import '../../../core/widgets/fullscreen_video_player.dart';
import '../../../core/widgets/inline_video_player.dart';
import '../../../core/widgets/kairo_avatar.dart';

const _kCardRadius = 16.0;
const _kInfoBg = Color(0xFF252525);
const _kFeedContentPadding = 12.0;

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.feedLayout = false,
    this.isOwner = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onIntercede,
    this.onEditContent,
    this.onDeleteText,
    this.onDeletePost,
  });

  final Post post;
  final bool feedLayout;
  final bool isOwner;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onIntercede;
  final Future<void> Function(String content)? onEditContent;
  final Future<void> Function()? onDeleteText;
  final Future<void> Function()? onDeletePost;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: widget.post.content);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: const Text('Editar publicación', style: TextStyle(color: KairoColors.darkText)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 3,
          style: const TextStyle(color: KairoColors.darkText),
          decoration: InputDecoration(
            hintText: 'Escribe tu mensaje...',
            hintStyle: TextStyle(color: KairoColors.darkTextSecondary.withValues(alpha: 0.7)),
            filled: true,
            fillColor: KairoColors.darkBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar', style: TextStyle(color: KairoColors.primary400)),
          ),
        ],
      ),
    );
    if (saved == null || !mounted) return;
    try {
      await widget.onEditContent?.call(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo editar: $e')));
      }
    }
  }

  Future<void> _confirmDeleteText() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: const Text('Eliminar texto', style: TextStyle(color: KairoColors.darkText)),
        content: const Text(
          '¿Eliminar solo el texto? Las fotos o videos se mantendrán.',
          style: TextStyle(color: KairoColors.darkTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar texto', style: TextStyle(color: KairoColors.errorText)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.onDeleteText?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar el texto: $e')));
      }
    }
  }

  Future<void> _confirmDeletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: const Text('Eliminar publicación', style: TextStyle(color: KairoColors.darkText)),
        content: const Text(
          '¿Eliminar esta publicación completa? Esta acción no se puede deshacer.',
          style: TextStyle(color: KairoColors.darkTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: KairoColors.errorText)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.onDeletePost?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'edit':
        _showEditDialog();
      case 'delete_text':
        _confirmDeleteText();
      case 'delete_post':
        _confirmDeletePost();
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final media = post.mediaItems;
    final hasMedia = media.isNotEmpty;
    final charLimit = hasMedia ? 150 : 300;
    final shouldTruncate = post.content.length > charLimit;
    final body = shouldTruncate && !_expanded
        ? '${post.content.substring(0, charLimit)}...'
        : post.content;

    if (!widget.feedLayout) {
      return _ProfilePostCard(
        post: post,
        isOwner: widget.isOwner,
        hasMedia: hasMedia,
        media: media,
        body: body,
        shouldTruncate: shouldTruncate,
        expanded: _expanded,
        onMenuSelected: _onMenuSelected,
        onToggleExpand: () => setState(() => _expanded = !_expanded),
        onLike: widget.onLike,
        onComment: widget.onComment,
        onShare: widget.onShare,
        onIntercede: widget.onIntercede,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isDesktop = ResponsiveBreakpoints.isDesktopWidth(availableWidth);
        final edgeToEdge = !isDesktop;

        final card = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.isPrayer) _KindBanner.prayer(edgeToEdge: edgeToEdge),
            if (post.isTestimony) _KindBanner.testimony(edgeToEdge: edgeToEdge),
            if (hasMedia)
              isDesktop
                  ? ClipRRect(
                      borderRadius: (post.isPrayer || post.isTestimony)
                          ? BorderRadius.zero
                          : const BorderRadius.vertical(top: Radius.circular(_kCardRadius)),
                      child: _PostMedia(items: media, feed: true),
                    )
                  : _FeedMediaBlock(
                      items: media,
                      post: post,
                      onLike: widget.onLike,
                      onComment: widget.onComment,
                      onShare: widget.onShare,
                      onIntercede: widget.onIntercede,
                    ),
            _PostInfoPanel(
              post: post,
              isOwner: widget.isOwner,
              hasMediaAbove: hasMedia,
              edgeToEdge: edgeToEdge,
              body: body,
              shouldTruncate: shouldTruncate,
              expanded: _expanded,
              onMenuSelected: _onMenuSelected,
              onToggleExpand: () => setState(() => _expanded = !_expanded),
              onLike: widget.onLike,
              onComment: widget.onComment,
              onShare: widget.onShare,
              onIntercede: widget.onIntercede,
            ),
          ],
        );

        if (!isDesktop) {
          return ColoredBox(
            color: KairoColors.darkBg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [card],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.feedCardMaxWidth),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kCardRadius),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: card,
            ),
          ),
        );
      },
    );
  }
}

// ─── Feed: media recortada (altura fija) + tap → pantalla completa ──────────

const _kFeedMediaMaxHeight = 550.0;

Future<void> _openFeedMediaFullscreen(
  BuildContext context,
  MediaItem item, {
  VideoPlayerController? videoController,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FeedMediaFullscreenPage(
        item: item,
        videoController: videoController,
      ),
    ),
  );
}

class _FeedCroppedMedia extends StatefulWidget {
  const _FeedCroppedMedia({required this.item, required this.width});

  final MediaItem item;
  final double width;

  @override
  State<_FeedCroppedMedia> createState() => _FeedCroppedMediaState();
}

class _FeedCroppedMediaState extends State<_FeedCroppedMedia> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  final GlobalKey<FeedVideoVisibilityState> _visibilityKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _initFeedVideo();
    }
  }

  void _initFeedVideo() {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setVolume(1.0);
      controller.setLooping(true);
      controller.play();
      setState(() => _videoReady = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _visibilityKey.currentState?.refreshVisibility();
      });
    }).catchError((_) {
      if (mounted) setState(() => _videoReady = false);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openFullscreen() {
    final item = widget.item;
    if (!item.isVideo || _controller == null) {
      return _openFeedMediaFullscreen(context, item);
    }
    return _openFeedMediaFullscreen(context, item, videoController: _controller);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    Widget media;
    if (item.isVideo) {
      if (!_videoReady || _controller == null) {
        media = const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
        );
      } else {
        media = FeedVideoVisibility(
          key: _visibilityKey,
          controller: _controller!,
          child: InlineVideoPlayer(
            url: item.url,
            controller: _controller,
            height: _kFeedMediaMaxHeight,
            fit: BoxFit.cover,
            autoPlay: true,
            autoDispose: false,
            tapToTogglePlay: false,
            showPlayOverlay: false,
            onTap: _openFullscreen,
          ),
        );
      }
    } else {
      media = GestureDetector(
        onTap: () => _openFeedMediaFullscreen(context, item),
        child: CachedNetworkImage(
          imageUrl: item.url,
          width: widget.width,
          height: _kFeedMediaMaxHeight,
          fit: BoxFit.cover,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _kFeedMediaMaxHeight),
      child: SizedBox(
        width: widget.width,
        height: _kFeedMediaMaxHeight,
        child: ColoredBox(
          color: Colors.black,
          child: ClipRect(child: media),
        ),
      ),
    );
  }
}

class _FeedMediaBlock extends StatelessWidget {
  const _FeedMediaBlock({
    required this.items,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onIntercede,
  });

  final List<MediaItem> items;
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onIntercede;

  @override
  Widget build(BuildContext context) {
    final item = items.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: _kFeedMediaMaxHeight,
          width: w,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              _FeedCroppedMedia(item: item, width: w),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(_kFeedContentPadding, 10, _kFeedContentPadding, 28),
                    child: _PostActionsRow(
                      post: post,
                      onLike: onLike,
                      onComment: onComment,
                      onShare: onShare,
                      onIntercede: onIntercede,
                      light: true,
                      alignStart: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedMediaFullscreenPage extends StatelessWidget {
  const _FeedMediaFullscreenPage({
    required this.item,
    this.videoController,
  });

  final MediaItem item;
  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: item.isVideo && videoController != null
                  ? FullscreenVideoPlayer(controller: videoController!)
                  : item.isVideo
                      ? SizedBox(
                          width: size.width,
                          height: size.height,
                          child: InlineVideoPlayer(
                            url: item.url,
                            height: size.height,
                            fit: BoxFit.contain,
                            autoPlay: true,
                            tapToTogglePlay: false,
                          ),
                        )
                      : InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4,
                          child: CachedNetworkImage(
                            imageUrl: item.url,
                            fit: BoxFit.contain,
                            width: size.width,
                            height: size.height,
                          ),
                        ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feed: panel gris (perfil → texto → acciones) ───────────────────────────

class _PostInfoPanel extends StatelessWidget {
  const _PostInfoPanel({
    required this.post,
    required this.isOwner,
    required this.hasMediaAbove,
    required this.body,
    required this.shouldTruncate,
    required this.expanded,
    required this.onMenuSelected,
    required this.onToggleExpand,
    this.edgeToEdge = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onIntercede,
  });

  final Post post;
  final bool isOwner;
  final bool hasMediaAbove;
  final bool edgeToEdge;
  final String body;
  final bool shouldTruncate;
  final bool expanded;
  final void Function(String) onMenuSelected;
  final VoidCallback onToggleExpand;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onIntercede;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kInfoBg,
        borderRadius: edgeToEdge
            ? null
            : hasMediaAbove
                ? const BorderRadius.vertical(bottom: Radius.circular(_kCardRadius))
                : BorderRadius.circular(_kCardRadius),
      ),
      padding: EdgeInsets.fromLTRB(
        _kFeedContentPadding,
        edgeToEdge ? 8 : 10,
        _kFeedContentPadding,
        edgeToEdge ? 6 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PostAuthorRow(post: post, isOwner: isOwner, onMenuSelected: onMenuSelected),
          const SizedBox(height: 6),
          _PostActionsRow(
            post: post,
            onLike: onLike,
            onComment: onComment,
            onShare: onShare,
            onIntercede: onIntercede,
            alignStart: true,
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                body,
                style: const TextStyle(color: KairoColors.darkText, fontSize: 14, height: 1.35),
              ),
            ),
            if (shouldTruncate)
              GestureDetector(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    expanded ? 'Ver menos' : 'Leer más',
                    style: const TextStyle(color: KairoColors.primary400, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PostAuthorRow extends StatelessWidget {
  const _PostAuthorRow({
    required this.post,
    required this.isOwner,
    required this.onMenuSelected,
  });

  final Post post;
  final bool isOwner;
  final void Function(String) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final goProfile = post.isAnonymous
        ? null
        : () => context.push('/profile?userId=${post.author.id}');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        KairoAvatar(
          imageUrl: post.isAnonymous ? null : post.author.image,
          name: post.isAnonymous ? '?' : post.author.displayName,
          size: 36,
          onTap: goProfile,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: goProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.isAnonymous ? 'Anónimo' : post.author.displayName,
                  style: const TextStyle(
                    color: KairoColors.darkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatTimeAgo(post.createdAt),
                      style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Text('•', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: KairoColors.successText, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('Público', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isOwner)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: KairoColors.darkTextSecondary, size: 20),
            color: KairoColors.darkCard,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onSelected: onMenuSelected,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: KairoColors.darkText),
                    SizedBox(width: 12),
                    Text('Editar texto', style: TextStyle(color: KairoColors.darkText)),
                  ],
                ),
              ),
              if (post.content.isNotEmpty)
                const PopupMenuItem(
                  value: 'delete_text',
                  child: Row(
                    children: [
                      Icon(Icons.text_fields_outlined, size: 20, color: KairoColors.errorText),
                      SizedBox(width: 12),
                      Text('Eliminar texto', style: TextStyle(color: KairoColors.errorText)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete_post',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: KairoColors.errorText),
                    SizedBox(width: 12),
                    Text('Eliminar publicación', style: TextStyle(color: KairoColors.errorText)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _PostActionsRow extends StatelessWidget {
  const _PostActionsRow({
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onIntercede,
    this.light = false,
    this.alignStart = false,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onIntercede;
  final bool light;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final liked = post.isLiked;
    final interceded = post.hasInterceded;
    final base = light ? Colors.white : KairoColors.darkTextSecondary;
    final likeColor = liked ? (light ? const Color(0xFFFF8A8A) : Colors.red) : base;

    final chips = <Widget>[
      _ActionChip(
        icon: liked ? Icons.favorite : Icons.favorite_border,
        label: '${post.likesCount} Amén',
        color: likeColor,
        onTap: onLike,
        alignStart: alignStart,
      ),
      _ActionChip(
        icon: Icons.chat_bubble_outline,
        label: '${post.commentsCount} Comentar',
        color: base,
        onTap: onComment,
        alignStart: alignStart,
      ),
      if (post.isPrayer)
        _ActionChip(
          icon: Icons.volunteer_activism_outlined,
          label: interceded ? 'Intercediste' : '${post.intercessionsCount} Interceder',
          color: interceded ? KairoColors.primary400 : base,
          onTap: interceded ? null : onIntercede,
          alignStart: alignStart,
        )
      else
        _ActionChip(
          icon: Icons.share_outlined,
          label: '0 Compartir',
          color: base,
          onTap: onShare,
          alignStart: alignStart,
        ),
    ];

    if (alignStart) {
      return Wrap(
        spacing: 20,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      );
    }

    return Row(
      children: [
        Expanded(child: chips[0]),
        Expanded(child: chips[1]),
        Expanded(child: chips[2]),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
    this.alignStart = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final c = color ?? KairoColors.darkTextSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignStart ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Media ──────────────────────────────────────────────────────────────────

class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.items, this.feed = false});

  final List<MediaItem> items;
  final bool feed;

  static const _profileHeight = 280.0;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final item = items.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;

        if (feed) {
          return _FeedCroppedMedia(item: item, width: cardWidth);
        }

        if (item.isVideo) {
          return SizedBox(
            width: double.infinity,
            height: _profileHeight,
            child: InlineVideoPlayer(url: item.url, height: _profileHeight),
          );
        }

        return CachedNetworkImage(
          imageUrl: item.url,
          height: _profileHeight,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _KindBanner extends StatelessWidget {
  const _KindBanner.prayer({this.edgeToEdge = false}) : _prayer = true;
  const _KindBanner.testimony({this.edgeToEdge = false}) : _prayer = false;

  final bool _prayer;
  final bool edgeToEdge;

  @override
  Widget build(BuildContext context) {
    final topRadius = edgeToEdge ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(_kCardRadius));
    if (_prayer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]),
          borderRadius: topRadius,
        ),
        child: const Row(
          children: [
            Text('🙏', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text('Petición de oración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: KairoColors.buttonGradient,
        borderRadius: topRadius,
      ),
      child: const Row(
        children: [
          Text('✨', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text('Testimonio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Perfil (layout clásico, sin feedLayout) ────────────────────────────────

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
    required this.isOwner,
    required this.hasMedia,
    required this.media,
    required this.body,
    required this.shouldTruncate,
    required this.expanded,
    required this.onMenuSelected,
    required this.onToggleExpand,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onIntercede,
  });

  final Post post;
  final bool isOwner;
  final bool hasMedia;
  final List<MediaItem> media;
  final String body;
  final bool shouldTruncate;
  final bool expanded;
  final void Function(String) onMenuSelected;
  final VoidCallback onToggleExpand;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onIntercede;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(_kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 10),
            child: _PostAuthorRow(post: post, isOwner: isOwner, onMenuSelected: onMenuSelected),
          ),
          if (hasMedia) _PostMedia(items: media),
          if (post.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, hasMedia ? 10 : 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body, style: const TextStyle(color: KairoColors.darkText, fontSize: 15, height: 1.4)),
                  if (shouldTruncate)
                    GestureDetector(
                      onTap: onToggleExpand,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          expanded ? 'Ver menos' : 'Leer más',
                          style: const TextStyle(color: KairoColors.primary400, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1, color: KairoColors.darkBorder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: _PostActionsRow(
              post: post,
              onLike: onLike,
              onComment: onComment,
              onShare: onShare,
              onIntercede: onIntercede,
            ),
          ),
        ],
      ),
    );
  }
}
