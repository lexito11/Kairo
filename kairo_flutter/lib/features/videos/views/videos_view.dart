import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/post.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/feed_playback_focus_manager.dart';
import '../widgets/reels_video_player.dart';
import '../widgets/video_post_overlay.dart';
import '../../../core/widgets/bottom_navigation.dart';
import '../../auth/services/auth_service.dart';
import '../../posts/providers/posts_provider.dart';
import '../../posts/services/posts_repository.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../../posts/widgets/share_sheet.dart';

class VideosView extends StatefulWidget {
  const VideosView({super.key});

  @override
  State<VideosView> createState() => _VideosViewState();
}

class _VideosViewState extends State<VideosView> with RouteAware {
  final _pageController = PageController();
  final _repo = PostsRepository();
  int _currentPage = 0;
  bool _pageAnimating = false;
  bool _scrollSettled = true;
  bool _scrollListenerAttached = false;
  bool _routeActive = true;
  DateTime? _lastWheelStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().loadFeed(refresh: true, videoOnly: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _routeActive = false;
    FeedPlaybackFocusManager.instance.pauseAll();
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() {
    _routeActive = true;
    if (mounted) setState(() {});
  }

  void _attachScrollListener() {
    if (_scrollListenerAttached || !_pageController.hasClients) return;
    _scrollListenerAttached = true;
    _pageController.position.isScrollingNotifier.addListener(_onScrollingChanged);
  }

  void _detachScrollListener() {
    if (!_scrollListenerAttached || !_pageController.hasClients) return;
    _pageController.position.isScrollingNotifier.removeListener(_onScrollingChanged);
    _scrollListenerAttached = false;
  }

  void _onScrollingChanged() {
    if (!_pageController.hasClients || !mounted) return;
    final scrolling = _pageController.position.isScrollingNotifier.value;
    if (scrolling && _scrollSettled) {
      setState(() => _scrollSettled = false);
    } else if (!scrolling && !_scrollSettled) {
      setState(() => _scrollSettled = true);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    FeedPlaybackFocusManager.instance.pauseAll();
    _detachScrollListener();
    _pageController.dispose();
    super.dispose();
  }

  String? _videoUrl(Post post) {
    final items = post.mediaItems;
    for (final item in items) {
      if (item.isVideo) return item.url;
    }
    return post.mediaUrl;
  }

  Future<void> _goToPage(int index) async {
    if (!_pageController.hasClients || _pageAnimating) return;
    setState(() {
      _pageAnimating = true;
      _scrollSettled = false;
    });
    try {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pageAnimating = false;
          _scrollSettled = true;
        });
      }
    }
  }

  void _onVerticalWheel(PointerScrollEvent event, int itemCount) {
    if (itemCount <= 1 || _pageAnimating) return;

    final now = DateTime.now();
    if (_lastWheelStep != null &&
        now.difference(_lastWheelStep!) < const Duration(milliseconds: 350)) {
      return;
    }

    final delta = event.scrollDelta.dy;
    if (delta.abs() < 4) return;

    if (delta > 0 && _currentPage < itemCount - 1) {
      _lastWheelStep = now;
      _goToPage(_currentPage + 1);
    } else if (delta < 0 && _currentPage > 0) {
      _lastWheelStep = now;
      _goToPage(_currentPage - 1);
    }
  }

  void _openComments(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: postId,
        onCommentAdded: () => context.read<PostsProvider>().incrementCommentCount(postId),
      ),
    );
  }

  void _openShare(String postId, String preview) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(postId: postId, postPreview: preview),
    );
  }

  Future<void> _showEditDialog(Post post) async {
    final controller = TextEditingController(text: post.content);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: const Text('Editar publicación', style: TextStyle(color: KairoColors.darkText)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: KairoColors.darkText),
          decoration: const InputDecoration(hintText: 'Escribe tu mensaje...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    await context.read<PostsProvider>().updatePostContent(post.id, saved);
  }

  Future<void> _confirmDeleteText(Post post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: const Text('Eliminar texto', style: TextStyle(color: KairoColors.darkText)),
        content: const Text('¿Eliminar solo el texto?', style: TextStyle(color: KairoColors.darkTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: KairoColors.errorText))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<PostsProvider>().updatePostContent(post.id, '');
  }

  Future<void> _confirmDeletePost(Post post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: const Text('Eliminar publicación', style: TextStyle(color: KairoColors.darkText)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: KairoColors.darkTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: KairoColors.errorText))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<PostsProvider>().deletePost(post.id);
  }

  void _onMenuSelected(Post post, String value) {
    switch (value) {
      case 'edit':
        _showEditDialog(post);
      case 'delete_text':
        _confirmDeleteText(post);
      case 'delete_post':
        _confirmDeletePost(post);
    }
  }

  Widget _buildVideoPage({
    required Post post,
    required int index,
    required double pageHeight,
  }) {
    final provider = context.read<PostsProvider>();
    final url = _videoUrl(post);
    final shouldPlay = index == _currentPage && _scrollSettled && _routeActive;
    final uid = AuthService().currentUser?.id;
    final isOwner = uid != null && post.author.id == uid;
    final showFollow = uid != null && !isOwner;

    return SizedBox(
      height: pageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            ReelsVideoPlayer(
              url: url,
              height: pageHeight,
              active: shouldPlay,
            ),
          VideoPostOverlay(
            post: post,
            isOwner: isOwner,
            isFollowingAuthor: provider.isFollowing(post.author.id),
            followLoading: provider.isFollowLoading(post.author.id),
            onLike: () => provider.toggleLike(post.id),
            onComment: () => _openComments(post.id),
            onShare: () => _openShare(post.id, post.content),
            onToggleFollow: showFollow ? () async {
              try {
                await provider.toggleFollow(post.author.id);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
                  );
                }
              }
            } : null,
            onMenuSelected: isOwner ? (value) => _onMenuSelected(post, value) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostsProvider>();
    final videos = provider.posts.where(postHasVideo).toList();

    if (provider.loading && videos.isEmpty) {
      return Scaffold(
        backgroundColor: KairoColors.darkBg,
        body: const Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
        bottomNavigationBar: const KairoBottomNavigation(currentPath: '/videos'),
      );
    }

    if (videos.isEmpty) {
      return Scaffold(
        backgroundColor: KairoColors.darkBg,
        body: const Center(
          child: Text('No hay videos aún', style: TextStyle(color: KairoColors.darkTextSecondary)),
        ),
        bottomNavigationBar: const KairoBottomNavigation(currentPath: '/videos'),
      );
    }

    final pageView = LayoutBuilder(
      builder: (context, constraints) {
        final pageHeight = constraints.maxHeight;
        _attachScrollListener();

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: kIsWeb
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(parent: ClampingScrollPhysics()),
          itemCount: videos.length,
          onPageChanged: (i) {
            setState(() => _currentPage = i);
            _repo.recordView(videos[i].id, 5);
          },
          itemBuilder: (context, i) => _buildVideoPage(
            post: videos[i],
            index: i,
            pageHeight: pageHeight,
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: kIsWeb
          ? Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _onVerticalWheel(event, videos.length);
                }
              },
              child: pageView,
            )
          : pageView,
      bottomNavigationBar: const KairoBottomNavigation(currentPath: '/videos'),
    );
  }
}
