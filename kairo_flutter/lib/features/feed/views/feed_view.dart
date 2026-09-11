import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/post.dart';
import '../../../core/providers/social_summary_provider.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/feed_playback_focus_manager.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../posts/providers/posts_provider.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../../posts/widgets/post_card.dart';
import '../../posts/widgets/share_sheet.dart';
import '../../bible/widgets/bible_icon.dart';
import '../../events/widgets/events_today_section.dart';
import '../../events/widgets/events_upcoming_section.dart';
import '../../stories/widgets/stories_strip.dart';
import '../../users/services/users_repository.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      FeedPlaybackFocusManager.instance.pauseAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FeedPlaybackFocusManager.instance.pauseAll();
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(postId: postId, postPreview: preview),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<PostsProvider, ({bool emptyLoading, String? emptyError, int itemCount})>(
      (p) => (
        emptyLoading: p.loading && p.posts.isEmpty,
        emptyError: p.posts.isEmpty ? p.error : null,
        itemCount: p.posts.length + (p.loadingMore ? 1 : 0),
      ),
    );

    final topInset = MediaQuery.paddingOf(context).top;
    final headerHeight = topInset + 44;

    return MainScaffold(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: RefreshIndicator(
          color: KairoColors.primary500,
          onRefresh: () => context.read<PostsProvider>().loadFeed(refresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 280,
            slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _FeedHeaderDelegate(height: headerHeight),
            ),
            const SliverToBoxAdapter(
              child: RepaintBoundary(child: StoriesStrip()),
            ),
            if (snapshot.emptyLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
              )
            else if (snapshot.emptyError != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(snapshot.emptyError!, style: const TextStyle(color: KairoColors.errorText)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.read<PostsProvider>().loadFeed(refresh: true),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final postsLen = context.read<PostsProvider>().posts.length;
                      if (i >= postsLen) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
                        );
                      }
                      return _FeedListItem(
                        key: ValueKey(context.read<PostsProvider>().posts[i].id),
                        index: i,
                        onComment: _openComments,
                        onShare: _openShare,
                      );
                    },
                    childCount: snapshot.itemCount,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    findChildIndexCallback: (key) {
                      if (key is! ValueKey<String>) return null;
                      final idx = context.read<PostsProvider>().posts.indexWhere((p) => p.id == key.value);
                      return idx < 0 ? null : idx;
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _FeedListItem extends StatelessWidget {
  const _FeedListItem({
    super.key,
    required this.index,
    required this.onComment,
    required this.onShare,
  });

  final int index;
  final void Function(String postId) onComment;
  final void Function(String postId, String preview) onShare;

  @override
  Widget build(BuildContext context) {
    return Selector<PostsProvider, ({Post post, bool isOwner, bool isFollowing, bool followLoading, bool showFollow})>(
      selector: (_, provider) {
        final post = provider.posts[index];
        final uid = AuthService().currentUser?.id;
        final isOwner = uid != null && post.author.id == uid;
        return (
          post: post,
          isOwner: isOwner,
          isFollowing: provider.isFollowing(post.author.id),
          followLoading: provider.isFollowLoading(post.author.id),
          showFollow: uid != null && !isOwner,
        );
      },
      builder: (context, slot, _) {
        final provider = context.read<PostsProvider>();
        final post = slot.post;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                feedLayout: true,
                isOwner: slot.isOwner,
                isFollowingAuthor: slot.isFollowing,
                followLoading: slot.followLoading,
                onLike: () => provider.toggleLike(post.id),
                onComment: () => onComment(post.id),
                onShare: () => onShare(post.id, post.content),
                onIntercede: () => provider.toggleIntercede(post.id),
                onToggleFollowAuthor: slot.showFollow
                    ? () async {
                        try {
                          await provider.toggleFollow(post.author.id);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
                            );
                          }
                        }
                      }
                    : null,
                onEditContent: (content) => provider.updatePostContent(post.id, content),
                onDeleteText: () => provider.updatePostContent(post.id, ''),
                onDeletePost: () => provider.deletePost(post.id),
              ),
            ),
            if (index == 1) const EventsTodaySection(inFeed: true),
            if (index == 2) const EventsUpcomingSection(inFeed: true),
            Divider(
              height: 8,
              thickness: 4,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ],
        );
      },
    );
  }
}

class _FeedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FeedHeaderDelegate({required this.height});

  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return const ColoredBox(
      color: KairoColors.darkBg,
      child: _FeedHeader(),
    );
  }

  @override
  bool shouldRebuild(covariant _FeedHeaderDelegate old) => old.height != height;
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Padding(
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
              _FeedHeaderButton(
                tooltip: 'Buscar',
                icon: const _FeedHeaderGlyph(Icons.search_rounded, color: KairoColors.darkText),
                onPressed: () {
                  FeedPlaybackFocusManager.instance.pauseAll();
                  context.push('/search');
                },
              ),
              _FeedHeaderButton(
                tooltip: 'Biblia',
                icon: const BibleIcon(color: KairoColors.primary400, size: _feedHeaderIconSize),
                onPressed: () {
                  FeedPlaybackFocusManager.instance.pauseAll();
                  context.push('/bible');
                },
              ),
              _FeedHeaderButton(
                tooltip: 'Eventos',
                icon: const _FeedHeaderGlyph(Icons.calendar_month_outlined, color: KairoColors.darkText),
                onPressed: () {
                  FeedPlaybackFocusManager.instance.pauseAll();
                  context.push('/events');
                },
              ),
              _FeedHeaderButton(
                tooltip: 'En vivo',
                icon: const _FeedHeaderGlyph(Icons.live_tv_rounded, color: KairoColors.primary500),
                onPressed: () {
                  FeedPlaybackFocusManager.instance.pauseAll();
                  context.push('/live');
                },
              ),
              _FeedHeaderButton(
                tooltip: 'Solicitudes',
                icon: const _FeedHeaderGlyph(Icons.person_add, color: KairoColors.darkText),
                onPressed: () {
                  FeedPlaybackFocusManager.instance.pauseAll();
                  context.push('/personas');
                },
              ),
            ],
          ),
        ),
    );
  }
}

const _feedHeaderIconSize = 24.0;

class _FeedHeaderButton extends StatelessWidget {
  const _FeedHeaderButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      iconSize: _feedHeaderIconSize,
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

class _FeedHeaderGlyph extends StatelessWidget {
  const _FeedHeaderGlyph(this.icon, {required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _feedHeaderIconSize,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Icon(icon, color: color, size: _feedHeaderIconSize),
      ),
    );
  }
}
