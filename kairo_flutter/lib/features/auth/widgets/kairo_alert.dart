import 'package:flutter/material.dart';
import '../../../core/theme/kairo_colors.dart';

enum KairoAlertType { error, success }

class KairoAlert extends StatelessWidget {
  const KairoAlert({super.key, required this.message, required this.type});

  final String message;
  final KairoAlertType type;

  @override
  Widget build(BuildContext context) {
    final isError = type == KairoAlertType.error;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? KairoColors.errorBg : KairoColors.successBg,
        border: Border.all(
          color: isError ? KairoColors.errorBorder : KairoColors.successBorder,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isError ? message : '✅ $message',
        style: TextStyle(
          fontSize: 14,
          color: isError ? KairoColors.errorText : KairoColors.successText,
        ),
      ),
    );
  }
}
