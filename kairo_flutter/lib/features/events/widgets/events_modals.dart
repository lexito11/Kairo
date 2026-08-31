import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../constants/church_countries.dart';
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
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
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

class ChurchRegistrationModal extends StatefulWidget {
  const ChurchRegistrationModal({super.key});

  @override
  State<ChurchRegistrationModal> createState() => _ChurchRegistrationModalState();
}

class _ChurchRegistrationModalState extends State<ChurchRegistrationModal> {
  Future<void> _pickLegalDocument(EventsProvider provider, ChurchFormData form) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    provider.updateChurchForm(
      form.copyWith(
        legalDocumentBytes: bytes,
        legalDocumentName: file.name,
        legalDocumentMime: _mimeForExtension(file.extension),
      ),
    );
  }

  String _mimeForExtension(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final form = provider.churchFormData;
    final isSouthAmerica = form.isSouthAmerica;
    final countrySelected = form.countryCode.isNotEmpty;

    return GestureDetector(
      onTap: () => provider.setShowChurchRegistration(false),
      child: Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Registrar mi iglesia',
                            style: TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => provider.setShowChurchRegistration(false),
                          style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                    const Text('País', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: form.countryCode.isEmpty ? null : form.countryCode,
                      dropdownColor: KairoColors.darkCard,
                      decoration: _inputDecoration('Selecciona tu país'),
                      items: churchCountries
                          .map((c) => DropdownMenuItem(
                                value: c.code,
                                child: Text(c.name, style: const TextStyle(color: KairoColors.darkText)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        final code = v ?? '';
                        final isSa = isSouthAmericaCountry(code);
                        provider.updateChurchForm(
                          form.copyWith(
                            countryCode: code,
                            fiscalId: isSa ? form.fiscalId : '',
                            facebookUrl: form.facebookUrl,
                            instagramUrl: form.instagramUrl,
                            clearLegalDocument: !isSa,
                          ),
                        );
                      },
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
                      label: 'Pastor o líder responsable',
                      value: form.responsibleLeader,
                      hint: 'Nombre del pastor o líder de la iglesia',
                      onChanged: (v) => provider.updateChurchForm(form.copyWith(responsibleLeader: v)),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Correo del pastor',
                      value: form.pastorEmail,
                      hint: 'correo@iglesia.com',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => provider.updateChurchForm(form.copyWith(pastorEmail: v)),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Crear contraseña',
                      value: form.password,
                      hint: 'Crea una contraseña',
                      obscure: true,
                      onChanged: (v) => provider.updateChurchForm(form.copyWith(password: v)),
                    ),
                    if (countrySelected && isSouthAmerica) ...[
                      const SizedBox(height: 20),
                      _FormField(
                        label: fiscalIdLabelForCountry(form.countryCode),
                        value: form.fiscalId,
                        hint: 'Ingresa el identificador fiscal de la iglesia',
                        onChanged: (v) => provider.updateChurchForm(form.copyWith(fiscalId: v)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Documento legal (foto o PDF)',
                        style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: provider.churchSubmitting ? null : () => _pickLegalDocument(provider, form),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KairoColors.primary400,
                          side: const BorderSide(color: KairoColors.primary500),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                        icon: Icon(form.hasLegalDocument ? Icons.check_circle : Icons.upload_file),
                        label: Text(
                          form.hasLegalDocument
                              ? (form.legalDocumentName ?? 'Documento seleccionado')
                              : 'Subir foto o PDF del documento legal',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FormField(
                        label: 'Link de Facebook',
                        value: form.facebookUrl,
                        hint: 'https://facebook.com/tu-iglesia',
                        onChanged: (v) => provider.updateChurchForm(form.copyWith(facebookUrl: v)),
                      ),
                      const SizedBox(height: 16),
                      _FormField(
                        label: 'Link de Instagram',
                        value: form.instagramUrl,
                        hint: 'https://instagram.com/tu-iglesia',
                        onChanged: (v) => provider.updateChurchForm(form.copyWith(instagramUrl: v)),
                      ),
                    ],
                    if (countrySelected && !isSouthAmerica) ...[
                      const SizedBox(height: 20),
                      _FormField(
                        label: 'Link de Facebook',
                        value: form.facebookUrl,
                        hint: 'https://facebook.com/tu-iglesia (opcional si tienes Instagram)',
                        onChanged: (v) => provider.updateChurchForm(form.copyWith(facebookUrl: v)),
                      ),
                      const SizedBox(height: 16),
                      _FormField(
                        label: 'Link de Instagram',
                        value: form.instagramUrl,
                        hint: 'https://instagram.com/tu-iglesia (opcional si tienes Facebook)',
                        onChanged: (v) => provider.updateChurchForm(form.copyWith(instagramUrl: v)),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KairoColors.primary500.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: KairoColors.primary500.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: KairoColors.primary400, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tu iglesia quedará activa cuando 10 miembros se unan y den fe de ella en la app.',
                                style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (provider.churchSubmitError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        provider.churchSubmitError!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: provider.churchSubmitting ? null : () => provider.setShowChurchRegistration(false),
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
                            onPressed: form.isValid && !provider.churchSubmitting
                                ? provider.submitChurchRegistration
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KairoColors.primary500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: provider.churchSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Registrar'),
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
    this.keyboardType,
  });

  final String label;
  final String value;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
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
          keyboardType: keyboardType,
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

class DenominationNoticeModal extends StatelessWidget {
  const DenominationNoticeModal({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final topInset = MediaQuery.paddingOf(context).top + 108;

    return GestureDetector(
      onTap: () => provider.setShowDenominationDropdown(false),
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: Stack(
          children: [
            Positioned(
              top: topInset,
              left: 16,
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  elevation: 24,
                  borderRadius: BorderRadius.circular(12),
                  color: KairoColors.darkCard,
                  shadowColor: Colors.black.withValues(alpha: 0.5),
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KairoColors.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            'TU DENOMINACIÓN',
                            style: TextStyle(
                              color: KairoColors.darkTextSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (provider.selectedDenomination != null)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: KairoColors.primary500.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: KairoColors.primary500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    provider.displayDenomination,
                                    style: const TextStyle(
                                      color: KairoColors.primary400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.check, size: 16, color: KairoColors.primary400),
                              ],
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAB308).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ No se puede cambiar',
                                style: TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tu denominación no se puede cambiar directamente. Si necesitas cambiarla, debes hacer una petición válida.',
                                style: TextStyle(
                                  color: KairoColors.darkTextSecondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: KairoColors.darkBorder),
                        GestureDetector(
                          onTap: provider.openDenominationChangeForm,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Text(
                              'Solicitar cambio de denominación',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: KairoColors.primary400, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DenominationChangeFormModal extends StatefulWidget {
  const DenominationChangeFormModal({super.key});

  @override
  State<DenominationChangeFormModal> createState() => _DenominationChangeFormModalState();
}

class _DenominationChangeFormModalState extends State<DenominationChangeFormModal> {
  late final TextEditingController _excuse;

  @override
  void initState() {
    super.initState();
    _excuse = TextEditingController();
  }

  @override
  void dispose() {
    _excuse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EventsProvider>();
    return GestureDetector(
      onTap: provider.closeDenominationChangeForm,
      behavior: HitTestBehavior.opaque,
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
                      const Expanded(
                        child: Text(
                          'Cambio de denominación',
                          style: TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: provider.closeDenominationChangeForm,
                        style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _excuse,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: KairoColors.primary500,
                    decoration: _inputDecoration('excusa aquí'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: provider.closeDenominationChangeForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KairoColors.primary500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Enviar'),
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

class ChurchReviewNoticeModal extends StatelessWidget {
  const ChurchReviewNoticeModal({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final rejected = provider.reviewNoticeRejected;

    return GestureDetector(
      onTap: () => provider.clearChurchReviewNotice(),
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: IgnorePointer(
            child: Container(
              margin: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                    size: 48,
                    color: rejected ? Colors.red : const Color(0xFFFBBF24),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    provider.reviewNoticeTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: rejected ? Colors.red : KairoColors.darkText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!rejected) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pendiente',
                        style: TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    provider.reviewNoticeMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Toca en cualquier lugar para cerrar',
                    style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
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

class EventRequestModal extends StatelessWidget {
  const EventRequestModal({super.key});

  Future<void> _pickDate(BuildContext context, EventsProvider provider) async {
    final form = provider.eventRequestForm;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: form.date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: KairoColors.primary500,
              surface: KairoColors.darkCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      provider.updateEventRequestForm(form.copyWith(date: picked));
    }
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Selecciona la fecha';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final form = provider.eventRequestForm;

    return GestureDetector(
      onTap: () => provider.setShowEventRequestForm(false),
      child: Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Solicitar evento',
                              style: TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () => provider.setShowEventRequestForm(false),
                            style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu iglesia: ${provider.myChurch?.name ?? 'Aprobada'}',
                        style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      _FormField(
                        label: 'Título del evento',
                        value: form.title,
                        hint: 'Ej. Conferencia de jóvenes',
                        onChanged: (v) => provider.updateEventRequestForm(form.copyWith(title: v)),
                      ),
                      const SizedBox(height: 16),
                      const Text('Tipo de evento', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: form.category.isEmpty ? null : form.category,
                        dropdownColor: KairoColors.darkCard,
                        decoration: _inputDecoration('Selecciona un tipo'),
                        items: christianEventTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: KairoColors.darkText))))
                            .toList(),
                        onChanged: (v) => provider.updateEventRequestForm(form.copyWith(category: v ?? '')),
                      ),
                      const SizedBox(height: 16),
                      _FormField(
                        label: 'Ubicación',
                        value: form.location,
                        hint: 'Ciudad o dirección del evento',
                        onChanged: (v) => provider.updateEventRequestForm(form.copyWith(location: v)),
                      ),
                      const SizedBox(height: 16),
                      const Text('Fecha', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: provider.eventSubmitting ? null : () => _pickDate(context, provider),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KairoColors.darkText,
                          side: const BorderSide(color: KairoColors.darkBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.calendar_today, size: 18, color: KairoColors.primary400),
                        label: Text(_dateLabel(form.date)),
                      ),
                      const SizedBox(height: 16),
                      _FormField(
                        label: 'Hora',
                        value: form.time,
                        hint: '19:00',
                        keyboardType: TextInputType.datetime,
                        onChanged: (v) => provider.updateEventRequestForm(form.copyWith(time: v)),
                      ),
                      const SizedBox(height: 16),
                      _FormField(
                        label: 'Descripción',
                        value: form.description,
                        hint: 'Cuéntanos de qué se trata el evento',
                        onChanged: (v) => provider.updateEventRequestForm(form.copyWith(description: v)),
                      ),
                      if (provider.eventSubmitError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          provider.eventSubmitError!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: provider.eventSubmitting ? null : () => provider.setShowEventRequestForm(false),
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
                              onPressed: form.isValid && !provider.eventSubmitting
                                  ? provider.submitEventRequest
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: KairoColors.primary500,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: provider.eventSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Enviar solicitud'),
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
      ),
    );
  }
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
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
