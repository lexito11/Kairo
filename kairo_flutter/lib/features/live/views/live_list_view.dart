import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/live_stream.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../services/live_feed_controller.dart';
import '../widgets/live_widgets.dart';

class LiveListView extends StatefulWidget {
  const LiveListView({super.key});

  @override
  State<LiveListView> createState() => _LiveListViewState();
}

class _LiveListViewState extends State<LiveListView> {
  final _feed = LiveFeedController.instance;

  @override
  void initState() {
    super.initState();
    _feed.ensureStarted();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/feed');
      },
      child: MainScaffold(
        child: AnimatedBuilder(
          animation: _feed,
          builder: (context, _) {
            final streams = _feed.streams;
            final featured = streams.isNotEmpty ? streams.first : null;
            final rest = streams.length > 1 ? streams.sublist(1) : const <LiveStream>[];

            return Column(
              children: [
                _LiveHeader(
                  onBack: () => context.go('/feed'),
                  onGoLive: () {
                    if (!AuthService().isSignedIn) {
                      context.push('/auth/signin');
                      return;
                    }
                    context.push('/live/go');
                  },
                  onRefresh: _feed.refresh,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: liveRed,
                    onRefresh: _feed.refresh,
                    child: _buildBody(featured, rest),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(LiveStream? featured, List<LiveStream> rest) {
    if (_feed.loading && !_feed.loaded) {
      return const Center(child: CircularProgressIndicator(color: liveRed));
    }
    if (_feed.error != null && _feed.streams.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.wifi_tethering_error, color: KairoColors.darkTextSecondary, size: 42),
          const SizedBox(height: 12),
          Text(
            _feed.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KairoColors.darkTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: _feed.refresh, child: const Text('Reintentar')),
          ),
        ],
      );
    }
    if (featured == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 48),
          Icon(Icons.wifi_tethering, color: KairoColors.darkTextSecondary, size: 42),
          SizedBox(height: 12),
          Text(
            'Nadie está en vivo ahora',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Cuando un hermano inicie una sala, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KairoColors.darkTextSecondary, height: 1.4),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _SectionLabel('DESTACADO'),
        const SizedBox(height: 10),
        _FeaturedCard(stream: featured),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionLabel('MÁS TRANSMISIONES'),
          const SizedBox(height: 10),
          ...rest.map((s) => _StreamTile(stream: s)),
        ],
      ],
    );
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({
    required this.onBack,
    required this.onGoLive,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final VoidCallback onGoLive;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top + 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En Vivo',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Salas activas ahora',
                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
          ),
          GestureDetector(
            onTap: onGoLive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: liveRed,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: liveRed.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Ir en Vivo',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: KairoColors.darkTextSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.stream});

  final LiveStream stream;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/live/${stream.id}'),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LiveStage(stream: stream, compact: true),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0x00000000), Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        const LiveBadge(showDot: true),
                        const SizedBox(width: 6),
                        LivePill(label: stream.orientation),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: LivePill(
                      icon: Icons.remove_red_eye_outlined,
                      label: formatLiveCount(stream.viewerCount),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        KairoAvatar(imageUrl: stream.host.image, name: stream.host.displayName, size: 32),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stream.host.displayName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              if (stream.tags.isNotEmpty)
                                Text(
                                  stream.tags.map((t) => '#$t').join(' '),
                                  style: const TextStyle(color: KairoColors.primary400, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            stream.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  const _StreamTile({required this.stream});

  final LiveStream stream;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/live/${stream.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 96,
                height: 54,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LiveStage(stream: stream, compact: true),
                    const Positioned(top: 6, left: 6, child: LiveBadge(compact: true)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stream.host.displayName,
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, size: 14, color: KairoColors.darkTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        formatLiveCount(stream.viewerCount),
                        style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      LivePill(label: stream.orientation, compact: true),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: KairoColors.darkTextSecondary),
          ],
        ),
      ),
    );
  }
}
