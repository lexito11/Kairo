import 'package:flutter/material.dart';

import '../../../core/theme/kairo_colors.dart';
import '../services/reports_repository.dart';

Future<void> showReportContentSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: KairoColors.darkCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReportContentSheet(targetType: targetType, targetId: targetId),
  );
}

class _ReportContentSheet extends StatefulWidget {
  const _ReportContentSheet({required this.targetType, required this.targetId});

  final ReportTargetType targetType;
  final String targetId;

  @override
  State<_ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<_ReportContentSheet> {
  final _repo = ReportsRepository();
  ReportReason? _reason;
  bool _sending = false;

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.submit(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias. Revisaremos este reporte.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reportar',
              style: TextStyle(
                color: KairoColors.darkText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Selecciona el motivo. No se volverá a mostrar el contenido.',
              style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      groupValue: _reason,
                      onChanged: _sending ? null : (v) => setState(() => _reason = v),
                      activeColor: KairoColors.primary500,
                      title: Text(
                        reason.label,
                        style: const TextStyle(color: KairoColors.darkText, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _reason == null || _sending ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: KairoColors.primary500),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar reporte'),
            ),
          ],
        ),
      ),
    );
  }
}
