import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../constants/events_constants.dart';
import '../models/event_data.dart';
import '../providers/events_provider.dart';
import 'event_cards.dart';

class EventDetailModal extends StatelessWidget {
  const EventDetailModal({super.key, required this.event});

  final EventData event;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<EventsProvider>().closeEvent(),
      child: Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      CachedNetworkImage(imageUrl: event.image, height: 192, width: double.infinity, fit: BoxFit.cover),
                      if (event.isLive) const Positioned(top: 12, left: 12, child: LiveBadge()),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IconButton(
                          onPressed: () => context.read<EventsProvider>().closeEvent(),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: KairoColors.primary500.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text(event.denomination, style: const TextStyle(color: KairoColors.primary400, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 4),
                            Text('• ${event.category}', style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(event.title, style: const TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _InfoRow(icon: Icons.access_time, text: event.time),
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.location_on_outlined, text: event.location),
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.church_outlined, text: event.church),
                        const SizedBox(height: 16),
                        const Text('Descripción', style: TextStyle(color: KairoColors.darkText, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(event.description, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, height: 1.5)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => context.read<EventsProvider>().handleAttending(event.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: KairoColors.primary500,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: const Text('Asistiré'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: KairoColors.darkHover,
                                  foregroundColor: KairoColors.darkText,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: const Text('Me interesa'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: KairoColors.darkTextSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13))),
      ],
    );
  }
}

class EventsFilterPanel extends StatelessWidget {
  const EventsFilterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();

    return GestureDetector(
      onTap: () => provider.setShowFilterPanel(false),
      child: Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(8),
              height: MediaQuery.sizeOf(context).height * 0.96,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text('Filtros', style: TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => provider.setShowFilterPanel(false),
                          style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                          icon: const Icon(Icons.close, color: KairoColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: KairoColors.darkBorder),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Denominaciones', style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Selecciona una o más', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13)),
                        const SizedBox(height: 12),
                        ...List.generate(christianDenominationCategories.length, (i) {
                          final name = christianDenominationCategories[i];
                          final isSelected = provider.selectedChristianCategories.contains(name);
                          final color = filterDenominationColors[i % filterDenominationColors.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.2) : KairoColors.darkHover,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => provider.toggleChristianCategory(name),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.5)) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                      const SizedBox(width: 12),
                                      Text(name, style: TextStyle(color: isSelected ? KairoColors.darkText : KairoColors.darkTextSecondary, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        const Text('Tipo de evento', style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          provider.selectedChristianTypes.isEmpty ? 'Todos' : 'Filtrando por tipo',
                          style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: christianEventTypes.map((tipo) {
                            final isSelected = provider.selectedChristianTypes.contains(tipo);
                            return FilterChip(
                              label: Text(tipo),
                              selected: isSelected,
                              onSelected: (_) => provider.toggleChristianType(tipo),
                              backgroundColor: KairoColors.darkHover,
                              selectedColor: KairoColors.primary500,
                              labelStyle: TextStyle(color: isSelected ? Colors.white : KairoColors.darkTextSecondary, fontSize: 13),
                              checkmarkColor: Colors.white,
                              side: BorderSide.none,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        const Text('Costo', style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _FilterOptionButton(label: 'Gratis')),
                            const SizedBox(width: 8),
                            Expanded(child: _FilterOptionButton(label: 'De pago')),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Cuándo', style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _FilterOptionButton(label: 'Hoy')),
                            const SizedBox(width: 8),
                            Expanded(child: _FilterOptionButton(label: 'Esta semana')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _FilterOptionButton(label: 'Este mes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOptionButton extends StatelessWidget {
  const _FilterOptionButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: KairoColors.darkHover, borderRadius: BorderRadius.circular(8)),
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: KairoColors.darkText, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

class ChurchRegistrationModal extends StatelessWidget {
  const ChurchRegistrationModal({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final form = provider.churchFormData;

    return GestureDetector(
      onTap: () => provider.setShowChurchRegistration(false),
      child: Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Registrar mi iglesia', style: TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold))),
                        IconButton(
                          onPressed: () => provider.setShowChurchRegistration(false),
                          style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                          icon: const Icon(Icons.close, color: KairoColors.darkTextSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _FormField(
                      label: 'Nombre de la iglesia',
                      value: form.name,
                      hint: 'Ingresa el nombre de tu iglesia',
                      onChanged: (v) => provider.updateChurchForm(form.copyWith(name: v)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Denominación', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: form.denomination.isEmpty ? null : form.denomination,
                      dropdownColor: KairoColors.darkCard,
                      decoration: _inputDecoration('Selecciona una denominación'),
                      items: denominationNames.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: KairoColors.darkText))))
                          .toList(),
                      onChanged: (v) => provider.updateChurchForm(form.copyWith(denomination: v ?? '')),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Ciudad',
                      value: form.city,
                      hint: 'Ingresa la ciudad',
                      onChanged: (v) => provider.updateChurchForm(form.copyWith(city: v)),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Crear contraseña',
                      value: form.password,
                      hint: 'Crea una contraseña',
                      obscure: true,
                      onChanged: (v) => provider.updateChurchForm(form.copyWith(password: v)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => provider.setShowChurchRegistration(false),
                            style: TextButton.styleFrom(
                              backgroundColor: KairoColors.darkHover,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Cancelar', style: TextStyle(color: KairoColors.darkTextSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: form.name.isNotEmpty && form.denomination.isNotEmpty && form.city.isNotEmpty && form.password.length >= 6
                                ? provider.submitChurchRegistration
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KairoColors.primary500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('Registrar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.obscure = false,
  });

  final String label;
  final String value;
  final String hint;
  final bool obscure;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          obscureText: obscure,
          style: const TextStyle(color: KairoColors.darkText),
          decoration: _inputDecoration(hint),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: KairoColors.darkTextSecondary.withValues(alpha: 0.7)),
    filled: true,
    fillColor: KairoColors.darkHover,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: KairoColors.darkBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: KairoColors.darkBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: KairoColors.primary500)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}

class SimpleInfoModal extends StatelessWidget {
  const SimpleInfoModal({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
  });

  final String title;
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold))),
                      IconButton(
                        onPressed: onClose,
                        style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                        icon: const Icon(Icons.close, color: KairoColors.darkTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(message, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
