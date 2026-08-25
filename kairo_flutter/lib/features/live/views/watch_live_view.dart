import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/live_stream.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../users/services/users_repository.dart';
import '../live_catalog.dart';

const _liveRed = Color(0xFFEF4444);
const _likePink = Color(0xFFF472B6);

class WatchLiveView extends StatefulWidget {
  const WatchLiveView({super.key, required this.streamId});

  final String streamId;

  @override
  State<WatchLiveView> createState() => _WatchLiveViewState();
}

class _WatchLiveViewState extends State<WatchLiveView> {
  final _chat = TextEditingController();
  final _scroll = ScrollController();
  bool _playing = true;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  Future<void> _join() async {
    if (_joined) return;
    _joined = true;
    final me = await UsersRepository().getCurrentUser();
    final name = me?.displayName ?? 'Invitado';
    LiveCatalog.instance.join(widget.streamId, name, me?.image);
  }

  @override
  void dispose() {
    _chat.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _chat.text.trim();
    if (text.isEmpty) return;
    if (!AuthService().isSignedIn) {
      context.push('/auth/signin');
      return;
    }
    final me = await UsersRepository().getCurrentUser();
    LiveCatalog.instance.sendMessage(
      streamId: widget.streamId,
      authorName: me?.displayName ?? 'Tú',
      authorImage: me?.image,
      content: text,
    );
    _chat.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _share(LiveStream stream) async {
    final origin = Uri.base.origin;
    final link = origin.isNotEmpty && origin != 'about:blank'
        ? '$origin/live/${stream.id}'
        : 'kairo://live/${stream.id}';
    await SharePlus.instance.share(ShareParams(text: '${stream.title}\n$link', subject: 'KAIRO En Vivo'));
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      child: AnimatedBuilder(
        animation: LiveCatalog.instance,
        builder: (context, _) {
          final stream = LiveCatalog.instance.byId(widget.streamId);
          if (stream == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Esta transmisión ya no está disponible', style: TextStyle(color: KairoColors.darkTextSecondary)),
                  TextButton(onPressed: () => context.go('/live'), child: const Text('Volver')),
                ],
              ),
            );
          }
          final messages = LiveCatalog.instance.messagesFor(stream.id);
          final liked = LiveCatalog.instance.isLiked(stream.id);
          final top = MediaQuery.paddingOf(context).top;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4, top + 2, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (stream.isHostSession) LiveCatalog.instance.endLive(stream.id);
                        context.canPop() ? context.pop() : context.go('/live');
                      },
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    KairoAvatar(imageUrl: stream.host.image, name: stream.host.displayName, size: 34),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stream.host.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: _liveRed, borderRadius: BorderRadius.circular(10)),
                                child: const Text(
                                  '● EN VIVO',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${formatLiveCount(stream.viewerCount)} espectadores',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => LiveCatalog.instance.toggleLike(stream.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _likePink.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(liked ? Icons.favorite : Icons.favorite_border, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              formatLiveCount(stream.likesCount),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _share(stream),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A2A),
                      ),
                      icon: const Icon(Icons.ios_share, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: stream.thumbnailUrl, fit: BoxFit.cover),
                        if (!_playing)
                          Container(color: Colors.black.withValues(alpha: 0.28)),
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(() => _playing = !_playing),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              KairoAvatar(imageUrl: m.authorImage, name: m.authorName, size: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: m.authorName,
                                        style: const TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      TextSpan(
                                        text: m.isJoin ? ' ${m.content}' : ' ${m.content}',
                                        style: TextStyle(
                                          color: m.isJoin ? KairoColors.darkTextSecondary : Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 28,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x000A0A0A), Color(0xFF0A0A0A)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chat,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                          filled: true,
                          fillColor: KairoColors.darkCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: KairoColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: KairoColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: KairoColors.primary500),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send, color: KairoColors.primary400),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
