import 'package:flutter/material.dart';

import '../../../core/theme/kairo_colors.dart';
import '../constants/events_constants.dart';

class DenominationSelector extends StatefulWidget {
  const DenominationSelector({super.key, required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  State<DenominationSelector> createState() => _DenominationSelectorState();
}

class _DenominationSelectorState extends State<DenominationSelector> {
  String? _selected;
  bool _showConfirmation = false;

  @override
  Widget build(BuildContext context) {
    if (_showConfirmation && _selected != null) {
      final denomination = denominationOptions.firstWhere((d) => d.id == _selected);
      return Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: KairoColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KairoColors.darkBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 32),
                ),
                const SizedBox(height: 16),
                const Text('¿Estás seguro?', style: TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'Has seleccionado: ',
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
                    children: [TextSpan(text: denomination.name, style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold))],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Importante', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w600, fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        'Una vez que confirmes tu denominación, no podrás cambiarla hasta que hagas una petición válida explicando el motivo del cambio. Esta decisión ayuda a mantener la integridad de nuestra comunidad.',
                        style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => setState(() { _showConfirmation = false; _selected = null; }),
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
                        onPressed: () => widget.onSelect(_selected!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KairoColors.primary500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            color: KairoColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KairoColors.darkBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: KairoColors.primary500.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.church_outlined, color: KairoColors.primary400, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('¿Cuál es tu denominación?', style: TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Selecciona tu denominación para ver eventos relevantes a tu fe',
                textAlign: TextAlign.center,
                style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: denominationOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = denominationOptions[i];
                    return Material(
                      color: KairoColors.darkHover,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() { _selected = d.id; _showConfirmation = true; }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: d.color, shape: BoxShape.circle)),
                              const SizedBox(width: 16),
                              Expanded(child: Text(d.name, style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w500))),
                              const Icon(Icons.chevron_right, color: KairoColors.darkTextSecondary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text('Esta información nos ayuda a mostrarte eventos relevantes', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
