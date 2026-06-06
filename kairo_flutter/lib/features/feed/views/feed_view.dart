import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/social_summary_provider.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../posts/providers/posts_provider.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../../posts/widgets/post_card.dart';
import '../../posts/widgets/share_sheet.dart';
import '../../stories/widgets/stories_strip.dart';
import '../../users/services/users_repository.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<PostsProvider>().loadFeed(refresh: true, videoOnly: false);
      if (!mounted || !AuthService().isSignedIn) return;
      final summary = await UsersRepository().getSocialSummary();
      if (mounted) {
        context.read<SocialSummaryProvider>().update(
              unread: summary.unreadCount,
              friends: summary.friendsCount,
            );
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<PostsProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(postId: postId, postPreview: preview),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostsProvider>();
    final summary = context.watch<SocialSummaryProvider>();

    return MainScaffold(
      child: RefreshIndicator(
        color: KairoColors.primary500,
        onRefresh: () => provider.loadFeed(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: KairoColors.darkBg.withValues(alpha: 0.95),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🙏', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  ShaderMask(
                    shaderCallback: (b) => KairoColors.brandTextGradient.createShader(b),
                    child: const Text('KAIRO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.live_tv_rounded, color: KairoColors.primary500),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Videos en vivo no disponibles hasta la proxima acttualizacio')),
                    );
                  },
                ),
                if (AuthService().isSignedIn)
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: KairoColors.darkText),
                        onPressed: () => context.push('/notifications'),
                      ),
                      if (summary.unreadCount > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: KairoColors.primary500, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SliverToBoxAdapter(child: StoriesStrip()),
            if (provider.loading && provider.posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
              )
            else if (provider.error != null && provider.posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.error!, style: const TextStyle(color: KairoColors.errorText)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: () => provider.loadFeed(refresh: true), child: const Text('Reintentar')),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= provider.posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
                        );
                      }
                      final post = provider.posts[i];
                      return PostCard(
                        post: post,
                        onLike: () => provider.toggleLike(post.id),
                        onComment: () => _openComments(post.id),
                        onShare: () => _openShare(post.id, post.content),
                        onIntercede: () => provider.toggleIntercede(post.id),
                      );
                    },
                    childCount: provider.posts.length + (provider.loadingMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
