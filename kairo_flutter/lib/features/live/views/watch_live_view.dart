import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/live_stream.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/bottom_navigation.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../users/services/users_repository.dart';
import '../live_browser_fullscreen.dart';
import '../services/live_feed_controller.dart';
import '../services/live_repository.dart';
import '../widgets/live_widgets.dart';

const _likePink = Color(0xFFF472B6);

class WatchLiveView extends StatefulWidget {
  const WatchLiveView({super.key, required this.streamId});

  final String streamId;

  @override
  State<WatchLiveView> createState() => _WatchLiveViewState();
}

class _WatchLiveViewState extends State<WatchLiveView> {
  final _repo = LiveRepository();
  final _chat = TextEditingController();
  final _scroll = ScrollController();

  LiveStream? _stream;
  final List<LiveChatMessage> _messages = [];
  final Set<String> _seenMessageIds = {};
  bool _liked = false;
  bool _loading = true;
  String? _error;
  bool _joined = false;
  bool _left = false;
  bool _sending = false;
  bool _chromeVisible = true;
  Orientation? _lastOrientation;
  Timer? _hideChrome;
  Timer? _qualify;
  Timer? _heartbeat;
  RealtimeChannel? _streamChannel;
  RealtimeChannel? _chatChannel;
  late final String _sessionKey;

  @override
  void initState() {
    super.initState();
    _sessionKey = _repo.newSessionKey();
    _bootstrap();
    listenBrowserFullscreen(() {
      if (!mounted) return;
      final cinema = _isCinema(context);
      _syncSystemUi(cinema);
      setState(() {
        if (isBrowserFullscreen) _chromeVisible = false;
      });
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stream = await _repo.fetchById(widget.streamId);
      if (!mounted) return;
      if (stream == null) {
        setState(() {
          _loading = false;
          _error = 'Esta transmisión ya no está disponible';
        });
        return;
      }
      final messages = await _repo.fetchMessages(widget.streamId);
      final liked = await _repo.isLiked(widget.streamId);
      if (!mounted) return;
      setState(() {
        _stream = stream;
        _messages
          ..clear()
          ..addAll(messages);
        _seenMessageIds
          ..clear()
          ..addAll(messages.map((m) => m.id));
        _liked = liked;
        _loading = false;
      });
      await _join(stream);
      _listen(stream);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _repo.mapError(e);
      });
    }
  }

  Future<void> _join(LiveStream stream) async {
    if (_joined || _left) return;
    try {
      await _repo.joinStream(stream.id, _sessionKey);
      _joined = true;
      if (AuthService().isSignedIn) {
        final me = await UsersRepository().getCurrentUser();
        if (me != null && !_left) {
          try {
            await _repo.sendMessage(stream.id, 'se unió al en vivo', join: true);
          } catch (_) {}
        }
      }
      if (stream.isHostSession) {
        await _repo.qualifyViewer(stream.id, _sessionKey);
      } else {
        _qualify = Timer(const Duration(seconds: 15), () {
          if (_left) return;
          _repo.qualifyViewer(stream.id, _sessionKey);
        });
      }
      if (stream.isHostSession) {
        _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
          _repo.heartbeat(stream.id);
        });
        await _repo.heartbeat(stream.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _repo.mapError(e));
    }
  }

  void _listen(LiveStream stream) {
    _streamChannel = _repo.subscribeStream(stream.id, (row) {
      if (!mounted || _stream == null) return;
      setState(() {
        _stream = _stream!.copyWith(
          viewerCount: (row['viewer_count'] as num?)?.toInt(),
          totalViewers: (row['total_viewers'] as num?)?.toInt(),
          likesCount: (row['likes_count'] as num?)?.toInt(),
          isLive: row['is_live'] as bool?,
        );
      });
    });
    _chatChannel = _repo.subscribeMessages(stream.id, (message) {
      if (!mounted || _seenMessageIds.contains(message.id)) return;
      setState(() {
        _seenMessageIds.add(message.id);
        _messages.add(message);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    final cinema = _isCinema(context);
    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      _hideChrome?.cancel();
      _chromeVisible = !cinema;
      _syncSystemUi(cinema);
    }
  }

  @override
  void dispose() {
    _left = true;
    _hideChrome?.cancel();
    _qualify?.cancel();
    _heartbeat?.cancel();
    _streamChannel?.unsubscribe();
    _chatChannel?.unsubscribe();
    final stream = _stream;
    if (stream != null) {
      if (stream.isHostSession && stream.isLive) {
        _repo.endLive(stream.id);
      }
      _repo.leaveStream(stream.id, _sessionKey);
    }
    _chat.dispose();
    _scroll.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _syncSystemUi(bool cinema) {
    if (cinema) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _revealChrome() {
    _hideChrome?.cancel();
    _hideChrome = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_isCinema(context)) {
        setState(() => _chromeVisible = false);
      }
    });
    if (!_chromeVisible) setState(() => _chromeVisible = true);
  }

  void _onCinemaTap() {
    if (_chromeVisible) {
      _hideChrome?.cancel();
      setState(() => _chromeVisible = false);
    } else {
      _revealChrome();
    }
  }

  Future<void> _onBack(LiveStream stream) async {
    if (stream.isHostSession && stream.isLive) {
      await _repo.endLive(stream.id);
      await LiveFeedController.instance.refresh();
    }
    if (isBrowserFullscreen) toggleBrowserFullscreen();
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/live');
  }

  Future<void> _send() async {
    final text = _chat.text.trim();
    if (text.isEmpty || _sending) return;
    if (!AuthService().isSignedIn) {
      context.push('/auth/signin');
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(widget.streamId, text);
      _chat.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_repo.mapError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike() async {
    if (!AuthService().isSignedIn) {
      context.push('/auth/signin');
      return;
    }
    try {
      final liked = await _repo.toggleLike(widget.streamId);
      if (!mounted) return;
      setState(() => _liked = liked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_repo.mapError(e))));
    }
  }

  Future<void> _share(LiveStream stream) async {
    final origin = Uri.base.origin;
    final link = origin.isNotEmpty && origin != 'about:blank'
        ? '$origin/live/${stream.id}'
        : 'kairo://live/${stream.id}';
    await SharePlus.instance.share(ShareParams(text: '${stream.title}\n$link', subject: 'KAIRO En Vivo'));
  }

  bool get _showDesktopFullscreen {
    return kIsWeb ||
        {
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        }.contains(defaultTargetPlatform);
  }

  bool _isCinema(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape || isBrowserFullscreen;
  }

  @override
  Widget build(BuildContext context) {
    final cinema = _isCinema(context);
    return MainScaffold(
      showBottomNav: !cinema,
      child: _buildBody(cinema),
    );
  }

  Widget _buildBody(bool cinema) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: liveRed));
    }
    final stream = _stream;
    if (stream == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Esta transmisión ya no está disponible', style: const TextStyle(color: KairoColors.darkTextSecondary)),
            TextButton(onPressed: () => context.go('/live'), child: const Text('Volver')),
          ],
        ),
      );
    }
    if (!stream.isLive) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_tethering_off, color: KairoColors.darkTextSecondary, size: 40),
            const SizedBox(height: 10),
            const Text('Esta sala ya terminó', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.go('/live'), child: const Text('Volver a En Vivo')),
          ],
        ),
      );
    }
    if (cinema) return _buildCinema(context, stream);
    return _buildPortrait(context, stream);
  }

  Widget _buildCinema(BuildContext context, LiveStream stream) {
    final path = GoRouterState.of(context).uri.path;
    return MouseRegion(
      onHover: (_) => _revealChrome(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LiveStage(stream: stream, hostLabel: stream.isHostSession),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onCinemaTap,
            child: const ColoredBox(color: Colors.transparent),
          ),
          IgnorePointer(
            ignoring: !_chromeVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _chromeVisible ? 1 : 0,
              child: Stack(
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xCC000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: _WatchHeader(
                        stream: stream,
                        liked: _liked,
                        overlay: true,
                        showFullscreen: _showDesktopFullscreen,
                        fullscreenOn: isBrowserFullscreen,
                        onBack: () => _onBack(stream),
                        onLike: _toggleLike,
                        onShare: () => _share(stream),
                        onFullscreen: () async {
                          await toggleBrowserFullscreen();
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: KairoBottomNavigation(currentPath: path),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, LiveStream stream) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, top + 2, 8, 8),
          child: _WatchHeader(
            stream: stream,
            liked: _liked,
            overlay: false,
            showFullscreen: _showDesktopFullscreen,
            fullscreenOn: isBrowserFullscreen,
            onBack: () => _onBack(stream),
            onLike: _toggleLike,
            onShare: () => _share(stream),
            onFullscreen: () async {
              await toggleBrowserFullscreen();
              if (mounted) setState(() {});
            },
          ),
        ),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LiveStage(stream: stream, hostLabel: stream.isHostSession),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(_error!, style: const TextStyle(color: KairoColors.errorText, fontSize: 12)),
          ),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Sé el primero en escribir en el chat',
                    style: TextStyle(color: KairoColors.darkTextSecondary),
                  ),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
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
                                        style: const TextStyle(
                                          color: KairoColors.primary400,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' ${m.content}',
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
                  enabled: !_sending,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: AuthService().isSignedIn
                        ? 'Escribe un mensaje...'
                        : 'Inicia sesión para comentar',
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
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, color: KairoColors.primary400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WatchHeader extends StatelessWidget {
  const _WatchHeader({
    required this.stream,
    required this.liked,
    required this.overlay,
    required this.showFullscreen,
    required this.fullscreenOn,
    required this.onBack,
    required this.onLike,
    required this.onShare,
    required this.onFullscreen,
  });

  final LiveStream stream;
  final bool liked;
  final bool overlay;
  final bool showFullscreen;
  final bool fullscreenOn;
  final VoidCallback onBack;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, overlay ? 2 : 0, 8, overlay ? 8 : 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
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
                      decoration: BoxDecoration(color: liveRed, borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        '● EN VIVO',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          children: [
                            TextSpan(text: '${formatLiveCount(stream.viewerCount)} espectadores'),
                            TextSpan(
                              text: '  ·  ${formatLiveCount(stream.qualifiedTotal)} en total',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLike,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: liked ? _likePink.withValues(alpha: 0.35) : _likePink.withValues(alpha: 0.9),
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
            onPressed: onShare,
            style: overlay ? null : IconButton.styleFrom(backgroundColor: const Color(0xFF2A2A2A)),
            icon: const Icon(Icons.ios_share, color: Colors.white, size: 18),
          ),
          if (showFullscreen)
            IconButton(
              onPressed: onFullscreen,
              icon: Icon(
                fullscreenOn ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }
}
