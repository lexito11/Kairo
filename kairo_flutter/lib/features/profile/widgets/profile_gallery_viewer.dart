import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../../posts/widgets/post_card.dart';

class ProfileGalleryViewer extends StatefulWidget {
  const ProfileGalleryViewer({
    super.key,
    required this.posts,
    required this.initialPostId,
    required this.onEditContent,
    required this.onDeleteText,
    required this.onDeletePost,
  });

  final List<Post> posts;
  final String initialPostId;
  final Future<void> Function(String postId, String content) onEditContent;
  final Future<void> Function(String postId) onDeleteText;
  final Future<void> Function(String postId) onDeletePost;

  @override
  State<ProfileGalleryViewer> createState() => _ProfileGalleryViewerState();
}

class _ProfileGalleryViewerState extends State<ProfileGalleryViewer> {
  final _scroll = ScrollController();
  late final List<GlobalKey> _keys;
  late final int _initialIndex;
  var _didJump = false;
  var _ready = false;
  var _jumpTries = 0;

  @override
  void initState() {
    super.initState();
    final idx = widget.posts.indexWhere((p) => p.id == widget.initialPostId);
    _initialIndex = idx < 0 ? 0 : idx;
    _keys = List.generate(widget.posts.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToOpened());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToOpened() {
    if (!mounted || _didJump) return;
    if (_initialIndex <= 0) {
      setState(() {
        _didJump = true;
        _ready = true;
      });
      return;
    }
    final ctx = _keys[_initialIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0, duration: Duration.zero);
      setState(() {
        _didJump = true;
        _ready = true;
      });
      return;
    }
    if (_jumpTries++ < 12 && _scroll.hasClients) {
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo((_scroll.offset + 900).clamp(0.0, max));
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToOpened());
      return;
    }
    if (mounted) setState(() => _ready = true);
  }

  void _openComments(BuildContext ctx, String postId) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.id;
    return Material(
      color: KairoColors.darkBg,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Opacity(
              opacity: _ready ? 1 : 0,
              child: ScrollConfiguration(
              behavior: const _NoBarScrollBehavior(),
              child: ListView.builder(
                controller: _scroll,
                cacheExtent: 50000,
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: widget.posts.length,
                itemBuilder: (context, i) {
                  final post = widget.posts[i];
                  final isOwner = uid != null && post.author.id == uid;
                  return KeyedSubtree(
                    key: _keys[i],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PostCard(
                          post: post,
                          feedLayout: true,
                          isOwner: isOwner,
                          onComment: () => _openComments(context, post.id),
                          onEditContent: (content) async {
                            await widget.onEditContent(post.id, content);
                            if (context.mounted) Navigator.pop(context);
                          },
                          onDeleteText: () async {
                            await widget.onDeleteText(post.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          onDeletePost: () async {
                            await widget.onDeletePost(post.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                        Divider(
                          height: 16,
                          thickness: 8,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ),
          ),
          Positioned(
            top: 0,
            right: 4,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBarScrollBehavior extends MaterialScrollBehavior {
  const _NoBarScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
