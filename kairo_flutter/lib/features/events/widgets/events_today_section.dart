import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../providers/events_provider.dart';
import 'event_cards.dart';

class EventsTodaySection extends StatelessWidget {
  const EventsTodaySection({super.key, this.onEventTap});

  final void Function(String eventId)? onEventTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final events = provider.todayEvents;
    if (events.isEmpty) return const SizedBox.shrink();

    return ColoredBox(
      color: KairoColors.darkBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                PulsingDot(size: 6),
                const SizedBox(width: 6),
                const Text('Hoy', style: TextStyle(color: KairoColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
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
