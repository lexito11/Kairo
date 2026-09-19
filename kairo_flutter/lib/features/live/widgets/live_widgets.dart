import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/models/live_stream.dart';
import '../../../core/widgets/kairo_avatar.dart';

const liveRed = Color(0xFFEF4444);

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.compact = false, this.showDot = false});
  final bool compact;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(color: liveRed, borderRadius: BorderRadius.circular(5)),
      child: Text(
        showDot ? '● EN VIVO' : 'EN VIVO',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 8 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class LivePill extends StatelessWidget {
  const LivePill({super.key, required this.label, this.icon, this.compact = false});

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
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class LiveStage extends StatelessWidget {
  const LiveStage({
    super.key,
    required this.stream,
    this.hostLabel = false,
    this.compact = false,
  });

  final LiveStream stream;
  final bool hostLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final image = stream.displayImage;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF141414)),
        if (image != null)
          CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: compact ? 0.2 : 0.35),
            colorBlendMode: BlendMode.darken,
            errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF141414)),
          ),
        if (compact)
          Center(
            child: KairoAvatar(imageUrl: stream.host.image, name: stream.host.displayName, size: 28),
          )
        else
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KairoAvatar(imageUrl: stream.host.image, name: stream.host.displayName, size: 72),
              const SizedBox(height: 10),
              const LiveBadge(showDot: true),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  hostLabel ? 'Estás en vivo' : stream.host.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hostLabel
                    ? 'Los hermanos se unen a tu sala'
                    : 'Sala en vivo · chat en tiempo real',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
