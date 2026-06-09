import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../auth/services/auth_service.dart';
import '../models/event_data.dart';
import '../providers/events_provider.dart';
import '../widgets/denomination_selector.dart';
import '../widgets/event_cards.dart';
import '../widgets/events_header.dart';
import '../widgets/events_modals.dart';
import '../widgets/events_today_section.dart' show PulsingDot;
class EventsView extends StatelessWidget {
  const EventsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();

    if (provider.isLoading) {
      return const MainScaffold(
        child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
      );
    }

    if (provider.showInitialSelector && AuthService().isSignedIn) {
      return MainScaffold(
        child: DenominationSelector(onSelect: provider.handleDenominationSelect),
      );
    }

    return MainScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              const EventsHeader(),
              Expanded(child: _EventsContent(provider: provider)),
            ],
          ),
          if (provider.selectedEvent != null) EventDetailModal(event: provider.selectedEvent!),
          if (provider.showFilterPanel) const EventsFilterPanel(),
          if (provider.showChurchRegistration) const ChurchRegistrationModal(),
          if (provider.showParticularesInactive)
            SimpleInfoModal(
              title: 'Particulares',
              message: 'Inactivo temporalmente hasta la nueva actualizacion',
              onClose: () => provider.setShowParticularesInactive(false),
            ),
          if (provider.showLiveSectionInfo)
            SimpleInfoModal(
              title: 'Transmisiones en vivo',
              message: 'Esta secion en para ver transmisiones en envivo y estara activo para la proxima actualización',
              onClose: () => provider.setShowLiveSectionInfo(false),
            ),
        ],
      ),
    );
  }
}

class _EventsContent extends StatelessWidget {
  const _EventsContent({required this.provider});

  final EventsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.activeFilter == EventFilterType.todos) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TodaySection(provider: provider),
          const SizedBox(height: 16),
          _UpcomingSection(provider: provider),
        ],
      );
    }

    return _FilteredList(provider: provider);
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.provider});

  final EventsProvider provider;

  @override
  Widget build(BuildContext context) {
    final events = provider.todayEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PulsingDot(size: 12),
            const SizedBox(width: 8),
            const Text('Hoy', style: TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(child: Text('No hay eventos para hoy', style: TextStyle(color: KairoColors.darkTextSecondary))),
          )
        else
          SizedBox(
            height: 380,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final event = events[i];
                return EventTodayCard(
                  event: event,
                  onTap: () => provider.openEvent(event),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.provider});

  final EventsProvider provider;

  @override
  Widget build(BuildContext context) {
    final events = provider.upcomingEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Próximos Eventos', style: TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (events.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(child: Text('No hay próximos eventos', style: TextStyle(color: KairoColors.darkTextSecondary))),
          )
        else
          SizedBox(
            height: 420,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final event = events[i];
                return EventUpcomingCard(
                  event: event,
                  attendance: provider.attendanceFor(event.id),
                  onTap: () => provider.openEvent(event),
                  onAttending: () => provider.handleAttending(event.id),
                  onNotAttending: () => provider.handleNotAttending(event.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FilteredList extends StatelessWidget {
  const _FilteredList({required this.provider});

  final EventsProvider provider;

  @override
  Widget build(BuildContext context) {
    final events = provider.filteredEvents;
    final title = switch (provider.activeFilter) {
      EventFilterType.hoy => 'Eventos de Hoy',
      EventFilterType.enVivo => 'En vivo',
      EventFilterType.proximos => 'Próximos Eventos',
      EventFilterType.todos => 'Eventos',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            if (provider.activeFilter == EventFilterType.hoy || provider.activeFilter == EventFilterType.enVivo) ...[
              const PulsingDot(size: 12),
              const SizedBox(width: 8),
            ],
            Text(title, style: const TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No hay eventos disponibles', style: TextStyle(color: KairoColors.darkTextSecondary))),
          )
        else
          ...events.map((event) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: EventFilteredCard(
                event: event,
                attendance: provider.attendanceFor(event.id),
                onTap: () => provider.openEvent(event),
                onAttending: () => provider.handleAttending(event.id),
                onNotAttending: () => provider.handleNotAttending(event.id),
              ),
            );
          }),
      ],
    );
  }
}
