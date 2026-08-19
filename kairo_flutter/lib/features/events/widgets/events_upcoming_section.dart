import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/events_provider.dart';
import 'event_cards.dart';

class EventsUpcomingSection extends StatelessWidget {
  const EventsUpcomingSection({super.key, this.onEventTap, this.inFeed = false});

  final void Function(String eventId)? onEventTap;
  /// Solo true cuando se inserta en el feed móvil (debajo de una tarjeta).
  final bool inFeed;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final events = provider.upcomingEvents;
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
              child: Text('Próximos Eventos', style: TextStyle(color: KairoColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
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
                return EventUpcomingCard(
                  event: event,
                  compact: true,
                  showAttendance: false,
                  attendance: provider.attendanceFor(event.id),
                  onTap: () {
                    if (onEventTap != null) {
                      onEventTap!(event.id);
                    } else {
                      context.push('/events');
                    }
                  },
                  onAttending: () => provider.handleAttending(event.id),
                  onNotAttending: () => provider.handleNotAttending(event.id),
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
