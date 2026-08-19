import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/events_provider.dart';
import 'event_cards.dart';

class EventsTodaySection extends StatelessWidget {
  const EventsTodaySection({super.key, this.onEventTap, this.inFeed = false});

  final void Function(String eventId)? onEventTap;
  /// Solo true cuando se inserta en el feed móvil (debajo de una tarjeta).
  final bool inFeed;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final events = provider.todayEvents;
    if (events.isEmpty) return const SizedBox.shrink();

    final feedTopInset = inFeed && !ResponsiveBreakpoints.isDesktop(context) ? 36.0 : 0.0;

    return ColoredBox(
      color: KairoColors.darkBg,
      child: Padding(
        padding: EdgeInsets.only(top: feedTopInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  PulsingDot(size: 6),
                  SizedBox(width: 6),
                  Text('Hoy', style: TextStyle(color: KairoColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final event = events[i];
                return EventTodayCard(
                  event: event,
                  compact: true,
                  onTap: () {
                    if (onEventTap != null) {
                      onEventTap!(event.id);
                    } else {
                      context.push('/events');
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        ),
      ),
    );
  }
}

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.size});

  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: const Color(0xFFF87171).withValues(alpha: 0.75 * (1 - _controller.value)),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
