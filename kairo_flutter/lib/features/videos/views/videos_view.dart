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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().loadFeed(refresh: true, videoOnly: true);
    });
  }

  @override
  void dispose() {
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
        body: const Center(child: Text('No hay videos aún', style: TextStyle(color: KairoColors.darkTextSecondary))),
        bottomNavigationBar: const KairoBottomNavigation(currentPath: '/videos'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        onPageChanged: (i) => _repo.recordView(videos[i].id, 5),
        itemBuilder: (context, i) {
          final post = videos[i];
          final url = _videoUrl(post);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (url != null) InlineVideoPlayer(url: url, height: MediaQuery.of(context).size.height, autoPlay: true),
              Positioned(
                left: 16,
                bottom: 100,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        KairoAvatar(imageUrl: post.author.image, name: post.author.displayName, size: 40),
                        const SizedBox(width: 10),
                        Text(post.author.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (post.content.isNotEmpty)
                      Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                    Text(formatTimeAgo(post.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 120,
                child: Column(
                  children: [
                    IconButton(
                      icon: Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, color: post.isLiked ? Colors.red : Colors.white),
                      onPressed: () => provider.toggleLike(post.id),
                    ),
                    Text('${post.likesCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const KairoBottomNavigation(currentPath: '/videos'),
    );
  }
}
