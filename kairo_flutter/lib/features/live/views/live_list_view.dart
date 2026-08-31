import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/live_stream.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../live_catalog.dart';

const _liveRed = Color(0xFFEF4444);

class LiveListView extends StatelessWidget {
  const LiveListView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      child: AnimatedBuilder(
        animation: LiveCatalog.instance,
        builder: (context, _) {
          final streams = LiveCatalog.instance.streams;
          final featured = streams.isNotEmpty ? streams.first : null;
          final rest = streams.length > 1 ? streams.sublist(1) : const <LiveStream>[];

          return Column(
            children: [
              _LiveHeader(
                onBack: () => context.canPop() ? context.pop() : context.go('/feed'),
                onGoLive: () {
                  if (!AuthService().isSignedIn) {
                    context.push('/auth/signin');
                    return;
                  }
                  context.push('/live/go');
                },
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const _SectionLabel('DESTACADO'),
                    const SizedBox(height: 10),
                    if (featured != null) _FeaturedCard(stream: featured),
                    const SizedBox(height: 22),
                    const _SectionLabel('MÁS TRANSMISIONES'),
                    const SizedBox(height: 10),
                    ...rest.map((s) => _StreamTile(stream: s)),
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

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({required this.onBack, required this.onGoLive});

  final VoidCallback onBack;
  final VoidCallback onGoLive;

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
                  'Transmisiones activas ahora',
                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onGoLive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _liveRed,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _liveRed.withValues(alpha: 0.45),
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
                  CachedNetworkImage(imageUrl: stream.thumbnailUrl, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0x00000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        const _LiveBadge(showDot: true),
                        const SizedBox(width: 6),
                        _Pill(label: stream.orientation),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _Pill(
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
                    CachedNetworkImage(imageUrl: stream.thumbnailUrl, fit: BoxFit.cover),
                    const Positioned(top: 6, left: 6, child: _LiveBadge(compact: true)),
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
                      _Pill(label: stream.orientation, compact: true),
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

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({this.compact = false, this.showDot = false});
  final bool compact;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(color: _liveRed, borderRadius: BorderRadius.circular(5)),
      child: Text(
        showDot ? '● EN VIVO' : 'EN VIVO',
        style: TextStyle(color: Colors.white, fontSize: compact ? 8 : 10, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon, this.compact = false});

  final String label;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: Colors.white, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
