import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kairo_colors.dart';
import '../constants/events_constants.dart';

class DenominationSelector extends StatefulWidget {
  const DenominationSelector({super.key, required this.onSelect, this.onBack});

  final ValueChanged<String> onSelect;
  final VoidCallback? onBack;

  @override
  State<DenominationSelector> createState() => _DenominationSelectorState();
}

class _DenominationSelectorState extends State<DenominationSelector> {
  String? _selected;
  bool _showConfirmation = false;

  bool _isMobile(double width) => width < 700;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = _isMobile(constraints.maxWidth);
        final hMargin = isMobile ? 8.0 : 16.0;
        final vMargin = isMobile ? 8.0 : 16.0;
        final cardWidth = math.min(
          isMobile ? constraints.maxWidth - hMargin * 2 : 480.0,
          constraints.maxWidth - hMargin * 2,
        );
        final cardHeight = isMobile
            ? constraints.maxHeight - vMargin * 2
            : math.min(560.0, constraints.maxHeight - vMargin * 2);

        if (_showConfirmation && _selected != null) {
          return _ConfirmationCard(
            denominationName: denominationOptions.firstWhere((d) => d.id == _selected).name,
            isMobile: isMobile,
            hMargin: hMargin,
            vMargin: vMargin,
            onCancel: () => setState(() {
              _showConfirmation = false;
              _selected = null;
            }),
            onConfirm: () => widget.onSelect(_selected!),
          );
        }

        return Material(
          color: Colors.black.withValues(alpha: 0.8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hMargin, vertical: vMargin),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  isMobile ? 16 : 24,
                  isMobile ? 16 : 24,
                  isMobile ? 12 : 20,
                ),
                decoration: BoxDecoration(
                  color: KairoColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Column(
                  children: [
                    Container(
                      width: isMobile ? 52 : 64,
                      height: isMobile ? 52 : 64,
                      decoration: BoxDecoration(
                        color: KairoColors.primary500.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.church_outlined,
                        color: KairoColors.primary400,
                        size: isMobile ? 26 : 32,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    const Text(
                      '¿Cuál es tu denominación?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KairoColors.darkText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona tu denominación para ver eventos relevantes a tu fe',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: ListView.separated(
                          itemCount: denominationOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final d = denominationOptions[i];
                            return Material(
                              color: KairoColors.darkHover,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() {
                                  _selected = d.id;
                                  _showConfirmation = true;
                                }),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: isMobile ? 16 : 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          d.name,
                                          style: const TextStyle(
                                            color: KairoColors.darkText,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: KairoColors.darkTextSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Esta información nos ayuda a mostrarte eventos relevantes',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
                    ),
                  ],
                    ),
                    if (widget.onBack != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.denominationName,
    required this.isMobile,
    required this.hMargin,
    required this.vMargin,
    required this.onCancel,
    required this.onConfirm,
  });

  final String denominationName;
  final bool isMobile;
  final double hMargin;
  final double vMargin;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hMargin, vertical: vMargin),
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 480),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: KairoColors.darkCard,
              borderRadius: BorderRadius.circular(16),
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
                const Text(
                  '¿Estás seguro?',
                  style: TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'Has seleccionado: ',
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
                    children: [
                      TextSpan(
                        text: denominationName,
                        style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
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
                        onPressed: onCancel,
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
                        onPressed: onConfirm,
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
      ),
    );
  }
}
