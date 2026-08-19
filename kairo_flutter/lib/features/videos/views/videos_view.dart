import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/inline_video_player.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/bottom_navigation.dart';
import '../../posts/providers/posts_provider.dart';
import '../../posts/services/posts_repository.dart';

class VideosView extends StatefulWidget {
  const VideosView({super.key});

  @override
  State<VideosView> createState() => _VideosViewState();
}

class _VideosViewState extends State<VideosView> {
  final _pageController = PageController();
  final _repo = PostsRepository();
  int _currentPage = 0;
  bool _pageAnimating = false;
  bool _scrollSettled = true;
  bool _scrollListenerAttached = false;
  DateTime? _lastWheelStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().loadFeed(refresh: true, videoOnly: true);
    });
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

  Widget _buildVideoPage({
    required Post post,
    required int index,
    required double pageHeight,
  }) {
    final provider = context.read<PostsProvider>();
    final url = _videoUrl(post);
    final shouldPlay = index == _currentPage && _scrollSettled;

    return SizedBox(
      height: pageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            InlineVideoPlayer(
              url: url,
              height: pageHeight,
              fit: BoxFit.cover,
              autoPlay: shouldPlay,
              tapToTogglePlay: true,
              showPlayOverlay: true,
            ),
          Positioned(
            left: 16,
            bottom: 24,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    KairoAvatar(
                      imageUrl: post.author.image,
                      name: post.author.displayName,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      post.author.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (post.content.isNotEmpty)
                  Text(
                    post.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                Text(
                  formatTimeAgo(post.createdAt),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 40,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : Colors.white,
                  ),
                  onPressed: () => provider.toggleLike(post.id),
                ),
                Text('${post.likesCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
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
