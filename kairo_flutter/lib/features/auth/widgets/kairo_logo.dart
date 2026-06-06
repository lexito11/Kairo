import 'package:flutter/material.dart';
import '../../../core/theme/kairo_colors.dart';

class KairoLogo extends StatelessWidget {
  const KairoLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: KairoColors.logoGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: KairoColors.primary500.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text('🙏', style: TextStyle(fontSize: size * 0.46)),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (bounds) =>
              KairoColors.brandTextGradient.createShader(bounds),
          child: Text(
            'KAIRO',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
