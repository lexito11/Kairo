import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/event_item.dart';
import '../../../core/theme/kairo_colors.dart';
import '../services/events_repository.dart';

class EventsView extends StatefulWidget {
  const EventsView({super.key});

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final _repo = EventsRepository();
  List<EventItem> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.fetchUpcoming();
      if (mounted) setState(() { _events = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Eventos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : RefreshIndicator(
              color: KairoColors.primary500,
              onRefresh: _load,
              child: _events.isEmpty
                  ? const ListBody(children: [SizedBox(height: 120, child: Center(child: Text('No hay eventos próximos', style: TextStyle(color: KairoColors.darkTextSecondary))))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _events.length,
                      itemBuilder: (_, i) {
                        final e = _events[i];
                        final dateStr = DateFormat('EEE d MMM · HH:mm', 'es').format(e.eventDate.toLocal());
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: KairoColors.darkCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: KairoColors.darkBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(gradient: KairoColors.buttonGradient, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.event, color: Colors.white),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title, style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w600)),
                                    if (e.location != null) Text(e.location!, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13)),
                                    Text(dateStr, style: const TextStyle(color: KairoColors.primary400, fontSize: 12)),
                                    if (e.description != null) ...[
                                      const SizedBox(height: 4),
                                      Text(e.description!, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
