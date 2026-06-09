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
import '../../events/widgets/events_today_section.dart';
import '../../events/widgets/events_upcoming_section.dart';
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
            SliverToBoxAdapter(child: _FeedHeader(summary: summary)),
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  StoriesStrip(),
                  SizedBox(height: 16),
                ],
              ),
            ),
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
                padding: const EdgeInsets.only(top: 8, bottom: 80),
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
                      final uid = AuthService().currentUser?.id;
                      final isOwner = uid != null && post.author.id == uid;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PostCard(
                            post: post,
                            feedLayout: true,
                            isOwner: isOwner,
                            onLike: () => provider.toggleLike(post.id),
                            onComment: () => _openComments(post.id),
                            onShare: () => _openShare(post.id, post.content),
                            onIntercede: () => provider.toggleIntercede(post.id),
                            onEditContent: (content) => provider.updatePostContent(post.id, content),
                            onDeleteText: () => provider.updatePostContent(post.id, ''),
                            onDeletePost: () => provider.deletePost(post.id),
                          ),
                          if (i == 1) const EventsTodaySection(),
                          if (i == 2) const EventsUpcomingSection(),
                          Divider(
                            height: 16,
                            thickness: 8,
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ],
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

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.summary});

  final SocialSummaryProvider summary;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: KairoColors.darkBg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, top + 2, 4, 2),
        child: SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('🙏', style: TextStyle(fontSize: 18, height: 1)),
              const SizedBox(width: 5),
              ShaderMask(
                shaderCallback: (b) => KairoColors.brandTextGradient.createShader(b),
                child: const Text(
                  'KAIRO',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                icon: const Icon(Icons.calendar_month_outlined, color: KairoColors.darkText, size: 22),
                onPressed: () => context.push('/events'),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                icon: const Icon(Icons.live_tv_rounded, color: KairoColors.primary500, size: 22),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Videos en vivo no disponibles hasta la proxima acttualizacio')),
                  );
                },
              ),
              if (AuthService().isSignedIn)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: const Icon(Icons.notifications_outlined, color: KairoColors.darkText, size: 22),
                      onPressed: () => context.push('/notifications'),
                    ),
                    if (summary.unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: KairoColors.primary500, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
