import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../models/estado_verificacion.dart';
import '../models/event_data.dart';
import '../providers/events_provider.dart';

class EventsHeader extends StatelessWidget {
  const EventsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: KairoColors.darkBg,
        border: Border(bottom: BorderSide(color: KairoColors.darkBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScopeTabs(provider: provider),
          const SizedBox(height: 16),
          _DenominationRow(provider: provider),
          const SizedBox(height: 16),
          _ActionsRow(provider: provider),
          const SizedBox(height: 12),
          _QuickFilters(provider: provider),
        ],
      ),
    );
  }
}

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({required this.provider});

  final EventsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ScopeTab(
          label: 'Cristianos',
          active: provider.eventScope == EventScope.cristianos,
          onTap: () => provider.setEventScope(EventScope.cristianos),
        ),
        if (provider.selectedDenomination != null) ...[
          const SizedBox(width: 24),
          _ScopeTab(
            label: provider.displayDenomination,
            active: provider.eventScope == EventScope.iglesia,
            onTap: () => provider.setEventScope(EventScope.iglesia),
          ),
        ],
      ],
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: active ? KairoColors.darkText : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? KairoColors.darkText : KairoColors.darkTextSecondary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _DenominationRow extends StatelessWidget {
  const _DenominationRow({required this.provider});

  final EventsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: KairoColors.primary500.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => provider.setShowDenominationDropdown(!provider.showDenominationDropdown),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.church_outlined, size: 16, color: KairoColors.primary400),
                      const SizedBox(width: 8),
                      Text(provider.displayDenomination, style: const TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: KairoColors.primary400),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Mostrando eventos de tu fe',
            style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionsRow extends StatefulWidget {
  const _ActionsRow({required this.provider});

  final EventsProvider provider;

  @override
  State<_ActionsRow> createState() => _ActionsRowState();
}

class _ActionsRowState extends State<_ActionsRow> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.provider.searchTerm);
  }

  @override
  void didUpdateWidget(covariant _ActionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider.searchTerm != _searchController.text) {
      _searchController.text = widget.provider.searchTerm;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.push('/live'),
              style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
              icon: const Icon(Icons.live_tv_outlined, color: KairoColors.darkTextSecondary),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: provider.setSearchTerm,
            style: const TextStyle(color: KairoColors.darkText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar eventos...',
              hintStyle: TextStyle(color: KairoColors.darkTextSecondary.withValues(alpha: 0.7), fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: KairoColors.darkTextSecondary),
              suffixIcon: provider.searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: KairoColors.darkTextSecondary),
                      onPressed: () {
                        _searchController.clear();
                        provider.clearSearch();
                      },
                    )
                  : null,
              filled: true,
              fillColor: KairoColors.darkHover,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: KairoColors.darkBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: KairoColors.darkBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: KairoColors.primary500)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (provider.myChurchStatus == EstadoVerificacion.pendiente)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAB308).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Pendiente', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ElevatedButton.icon(
          onPressed: provider.onCreateEventTap,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Crear Evento', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: KairoColors.primary500,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.provider});

  final EventsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipButton(label: 'Filtro', selected: false, onTap: () => provider.setShowFilterPanel(true)),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Todos',
            selected: provider.activeFilter == EventFilterType.todos,
            onTap: () => provider.setActiveFilter(EventFilterType.todos),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Hoy',
            selected: provider.activeFilter == EventFilterType.hoy,
            showDot: true,
            onTap: () => provider.setActiveFilter(EventFilterType.hoy),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'En vivo (${provider.liveCount})',
            selected: provider.activeFilter == EventFilterType.enVivo,
            isLive: true,
            onTap: () => provider.setActiveFilter(EventFilterType.enVivo),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Próximos',
            selected: provider.activeFilter == EventFilterType.proximos,
            showDot: true,
            onTap: () => provider.setActiveFilter(EventFilterType.proximos),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
    this.isLive = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showDot;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;

    if (isLive && selected) {
      bg = const Color(0xFFDC2626);
      fg = Colors.white;
      border = Border.all(color: const Color(0xFFEF4444));
    } else if (selected) {
      bg = KairoColors.primary500.withValues(alpha: 0.2);
      fg = KairoColors.primary400;
      border = null;
    } else {
      bg = KairoColors.darkHover;
      fg = KairoColors.darkTextSecondary;
      border = isLive ? Border.all(color: Colors.transparent) : null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24), border: border),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: isLive ? Colors.white : KairoColors.primary500, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            if (isLive) ...[
              const Icon(Icons.videocam, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(label, style: TextStyle(color: isLive && !selected ? KairoColors.darkTextSecondary : fg, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
