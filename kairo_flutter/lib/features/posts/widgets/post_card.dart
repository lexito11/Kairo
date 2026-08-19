import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/feed_playback_focus_manager.dart';
import '../../../core/widgets/feed_video_visibility.dart';
import '../../../core/widgets/feed_video_volume.dart';
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
                      child: _PostMedia(
                        items: media,
                        feed: true,
                        postId: post.id,
                        post: post,
                        isOwner: widget.isOwner,
                        onMenuSelected: _onMenuSelected,
                        onLike: widget.onLike,
                      ),
                    )
                  : _FeedMediaBlock(
                      items: media,
                      postId: post.id,
                      post: post,
                      isOwner: widget.isOwner,
                      onMenuSelected: _onMenuSelected,
                      onLike: widget.onLike,
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

// ─── Feed: recorte uniforme 4:5 → detalle con ratio real + Hero ───────────

/// Ratio fijo del feed (estilo Instagram): tarjetas uniformes con recorte leve.
const _kFeedDisplayAspectRatio = 4 / 5;

String _feedMediaHeroTag(String postId) => 'feed_media_$postId';

/// Calcula el tamaño del detalle respetando el aspect ratio real del archivo.
Size _detailMediaSize(double mediaAspectRatio, Size screen) {
  var width = screen.width;
  var height = width / mediaAspectRatio;
  if (height > screen.height) {
    height = screen.height;
    width = height * mediaAspectRatio;
  }
  return Size(width, height);
}

Future<void> _openFeedMediaFullscreen(
  BuildContext context, {
  required String heroTag,
  required MediaItem item,
  required double mediaAspectRatio,
  VideoPlayerController? videoController,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _FeedMediaFullscreenPage(
            heroTag: heroTag,
            item: item,
            mediaAspectRatio: mediaAspectRatio,
            videoController: videoController,
          ),
        );
      },
    ),
  );
}

/// Superficie compartida feed (cover) ↔ detalle (contain) para Hero unificado.
class _HeroMediaSurface extends StatelessWidget {
  const _HeroMediaSurface({
    required this.item,
    required this.fit,
    this.controller,
  });

  final MediaItem item;
  final BoxFit fit;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      final c = controller;
      if (c == null || !c.value.isInitialized) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
        );
      }
      final size = c.value.size;
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: FittedBox(
            fit: fit,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: IgnorePointer(
                child: VideoPlayer(c),
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: item.url,
          fit: fit,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}

Widget _buildFeedHero({
  required String heroTag,
  required Widget child,
}) {
  return Hero(
    tag: heroTag,
    createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
    flightShuttleBuilder: (
      flightContext,
      animation,
      flightDirection,
      fromHeroContext,
      toHeroContext,
    ) {
      final Hero toHero = toHeroContext.widget as Hero;
      return Material(
        color: Colors.black,
        child: toHero.child,
      );
    },
    child: Material(
      type: MaterialType.transparency,
      child: child,
    ),
  );
}

class _FeedMuteButton extends StatelessWidget {
  const _FeedMuteButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FeedVideoVolume.instance,
      builder: (context, _) {
        final muted = FeedVideoVolume.instance.isMuted;
        return Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: FeedVideoVolume.instance.toggle,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeedCroppedMedia extends StatefulWidget {
  const _FeedCroppedMedia({
    required this.item,
    required this.postId,
    required this.isSoloVideo,
    this.onLike,
  });

  final MediaItem item;
  final String postId;
  final bool isSoloVideo;
  final VoidCallback? onLike;

  @override
  State<_FeedCroppedMedia> createState() => _FeedCroppedMediaState();
}

class _FeedCroppedMediaState extends State<_FeedCroppedMedia> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  /// Aspect ratio real del archivo (solo para pantalla de detalle).
  double _mediaAspectRatio = _kFeedDisplayAspectRatio;
  final GlobalKey<FeedVideoVisibilityState> _visibilityKey = GlobalKey();

  String get _heroTag => _feedMediaHeroTag(widget.postId);

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _initFeedVideo();
    } else {
      _resolveImageAspectRatio();
    }
  }

  void _resolveImageAspectRatio() {
    final provider = CachedNetworkImageProvider(widget.item.url);
    final stream = provider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0 && w > 0 && mounted) {
        setState(() => _mediaAspectRatio = w / h);
      }
      stream.removeListener(listener!);
    });
    stream.addListener(listener);
  }

  void _initFeedVideo() {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
    _controller = controller;
    FeedVideoVolume.instance.register(controller);
    FeedPlaybackFocusManager.instance.register(controller);
    controller.initialize().then((_) {
      if (!mounted) return;
      final size = controller.value.size;
      if (size.width > 0 && size.height > 0) {
        _mediaAspectRatio = size.width / size.height;
      }
      FeedVideoVolume.instance.applyVolume(controller);
      controller.setLooping(true);
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
    if (_controller != null) {
      FeedVideoVolume.instance.unregister(_controller!);
      FeedPlaybackFocusManager.instance.unregister(_controller!);
      _controller!.dispose();
    }
    super.dispose();
  }

  void _openFullscreen() {
    final item = widget.item;
    if (item.isVideo && _controller != null) {
      _visibilityKey.currentState?.setVisibilityTrackingEnabled(false);
      FeedPlaybackFocusManager.instance.holdFocus(_controller!);
    }
    _openFeedMediaFullscreen(
      context,
      heroTag: _heroTag,
      item: item,
      mediaAspectRatio: _mediaAspectRatio,
      videoController: _controller,
    ).whenComplete(() {
      if (!mounted || !item.isVideo || _controller == null) return;
      FeedPlaybackFocusManager.instance.releaseHold(_controller!);
      _visibilityKey.currentState?.setVisibilityTrackingEnabled(true);
      _visibilityKey.currentState?.refreshVisibility();
    });
  }

  Widget _buildFeedSurface() {
    final item = widget.item;

    if (item.isVideo) {
      if (!_videoReady || _controller == null) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
        );
      }
      return FeedVideoVisibility(
        key: _visibilityKey,
        controller: _controller!,
        child: _HeroMediaSurface(
          item: item,
          fit: BoxFit.cover,
          controller: _controller,
        ),
      );
    }

    return _HeroMediaSurface(
      item: item,
      fit: BoxFit.cover,
      controller: _controller,
    );
  }

  Widget _buildMediaFrame() {
    return AspectRatio(
      aspectRatio: _kFeedDisplayAspectRatio,
      child: ClipRect(
        child: IgnorePointer(
          child: _buildFeedSurface(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frame = _buildMediaFrame();

    if (widget.isSoloVideo) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openFullscreen,
        child: _buildFeedHero(
          heroTag: _heroTag,
          child: frame,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onLike,
      onDoubleTap: widget.onLike,
      child: frame,
    );
  }
}

class _FeedFloatingAuthorHeader extends StatelessWidget {
  const _FeedFloatingAuthorHeader({
    required this.post,
    required this.isOwner,
    required this.onMenuSelected,
  });

  final Post post;
  final bool isOwner;
  final void Function(String) onMenuSelected;

  static const _kFloatMargin = 8.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _kFloatMargin,
      right: _kFloatMargin,
      bottom: _kFloatMargin,
      child: _PostAuthorRow(
        post: post,
        isOwner: isOwner,
        onMenuSelected: onMenuSelected,
        compact: true,
        light: true,
      ),
    );
  }
}

class _FeedMediaStack extends StatelessWidget {
  const _FeedMediaStack({
    required this.item,
    required this.postId,
    required this.post,
    required this.isOwner,
    required this.onMenuSelected,
    this.onLike,
  });

  final MediaItem item;
  final String postId;
  final Post post;
  final bool isOwner;
  final void Function(String) onMenuSelected;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        _FeedCroppedMedia(
          item: item,
          postId: postId,
          isSoloVideo: post.isSoloVideo,
          onLike: onLike,
        ),
        _FeedFloatingAuthorHeader(
          post: post,
          isOwner: isOwner,
          onMenuSelected: onMenuSelected,
        ),
        if (item.isVideo)
          const Positioned(
            top: 8,
            right: 8,
            child: _FeedMuteButton(),
          ),
      ],
    );
  }
}

class _FeedMediaBlock extends StatelessWidget {
  const _FeedMediaBlock({
    required this.items,
    required this.postId,
    required this.post,
    required this.isOwner,
    required this.onMenuSelected,
    this.onLike,
  });

  final List<MediaItem> items;
  final String postId;
  final Post post;
  final bool isOwner;
  final void Function(String) onMenuSelected;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final item = items.first;
    return _FeedMediaStack(
      item: item,
      postId: postId,
      post: post,
      isOwner: isOwner,
      onMenuSelected: onMenuSelected,
      onLike: onLike,
    );
  }
}

class _FeedMediaFullscreenPage extends StatelessWidget {
  const _FeedMediaFullscreenPage({
    required this.heroTag,
    required this.item,
    required this.mediaAspectRatio,
    this.videoController,
  });

  final String heroTag;
  final MediaItem item;
  final double mediaAspectRatio;
  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final detailSize = _detailMediaSize(mediaAspectRatio, screen);
    final isVideo = item.isVideo && videoController != null;

    Widget heroChild = SizedBox(
      width: detailSize.width,
      height: detailSize.height,
      child: _HeroMediaSurface(
        item: item,
        fit: BoxFit.contain,
        controller: videoController,
      ),
    );

    if (!item.isVideo) {
      heroChild = InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: heroChild,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          Center(
            child: Hero(
              tag: heroTag,
              createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
              flightShuttleBuilder: (
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
              ) {
                final Hero toHero = toHeroContext.widget as Hero;
                return Material(color: Colors.black, child: toHero.child);
              },
              child: Material(
                color: Colors.black,
                child: heroChild,
              ),
            ),
          ),
          if (isVideo)
            Positioned.fill(
              child: FullscreenVideoPlayer(
                controller: videoController!,
                showVideoLayer: false,
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
      padding: hasMediaAbove
          ? const EdgeInsets.fromLTRB(_kFeedContentPadding, 4, _kFeedContentPadding, 4)
          : EdgeInsets.fromLTRB(
              _kFeedContentPadding,
              edgeToEdge ? 5 : 7,
              _kFeedContentPadding,
              edgeToEdge ? 4 : 6,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasMediaAbove)
            _PostAuthorRow(
              post: post,
              isOwner: isOwner,
              onMenuSelected: onMenuSelected,
              compact: true,
            ),
          if (!hasMediaAbove) const SizedBox(height: 3),
          _PostActionsRow(
            post: post,
            onLike: onLike,
            onComment: onComment,
            onShare: onShare,
            onIntercede: onIntercede,
            alignStart: true,
          ),
          if (post.content.isNotEmpty) ...[
            SizedBox(height: hasMediaAbove ? 2 : 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                body,
                style: TextStyle(
                  color: KairoColors.darkText,
                  fontSize: hasMediaAbove ? 12 : 13,
                  height: 1.25,
                ),
              ),
            ),
            if (shouldTruncate)
              GestureDetector(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    expanded ? 'Ver menos' : 'Leer más',
                    style: const TextStyle(color: KairoColors.primary400, fontSize: 12, fontWeight: FontWeight.w600),
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
    this.compact = false,
    this.light = false,
  });

  final Post post;
  final bool isOwner;
  final void Function(String) onMenuSelected;
  final bool compact;
  final bool light;

  static const _kOverlayTextShadow = [
    Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 1)),
    Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static final _kAvatarOverlayShadow = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 6, offset: const Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final goProfile = post.isAnonymous
        ? null
        : () => context.push('/profile?userId=${post.author.id}');

    final nameColor = light ? Colors.white : KairoColors.darkText;
    final metaColor = light ? Colors.white70 : KairoColors.darkTextSecondary;
    final menuColor = light ? Colors.white : KairoColors.darkTextSecondary;

    final avatar = KairoAvatar(
      imageUrl: post.isAnonymous ? null : post.author.image,
      name: post.isAnonymous ? '?' : post.author.displayName,
      size: compact ? 32 : 36,
      onTap: goProfile,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        light
            ? DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: _kAvatarOverlayShadow),
                child: avatar,
              )
            : avatar,
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: GestureDetector(
            onTap: goProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.isAnonymous ? 'Anónimo' : post.author.displayName,
                  style: TextStyle(
                    color: nameColor,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
                    shadows: light ? _kOverlayTextShadow : null,
                  ),
                ),
                if (!light) ...[
                  SizedBox(height: compact ? 1 : 2),
                  Row(
                    children: [
                      Text(
                        formatTimeAgo(post.createdAt),
                        style: TextStyle(color: metaColor, fontSize: compact ? 11 : 12),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 5),
                        child: Text('•', style: TextStyle(color: metaColor, fontSize: compact ? 11 : 12)),
                      ),
                      Container(
                        width: compact ? 5 : 6,
                        height: compact ? 5 : 6,
                        decoration: const BoxDecoration(color: KairoColors.successText, shape: BoxShape.circle),
                      ),
                      SizedBox(width: compact ? 3 : 4),
                      Text('Público', style: TextStyle(color: metaColor, fontSize: compact ? 11 : 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isOwner)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: menuColor,
              size: 20,
              shadows: light ? _kOverlayTextShadow : null,
            ),
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
    this.alignStart = false,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onIntercede;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final liked = post.isLiked;
    final interceded = post.hasInterceded;
    const base = KairoColors.darkTextSecondary;
    final likeColor = liked ? Colors.red : base;

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
  const _PostMedia({
    required this.items,
    this.feed = false,
    this.postId = '',
    this.post,
    this.isOwner = false,
    this.onMenuSelected,
    this.onLike,
  });

  final List<MediaItem> items;
  final bool feed;
  final String postId;
  final Post? post;
  final bool isOwner;
  final void Function(String)? onMenuSelected;
  final VoidCallback? onLike;

  static const _profileHeight = 280.0;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final item = items.first;

    if (feed && post != null && onMenuSelected != null) {
      return _FeedMediaStack(
        item: item,
        postId: postId,
        post: post!,
        isOwner: isOwner,
        onMenuSelected: onMenuSelected!,
        onLike: onLike,
      );
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
