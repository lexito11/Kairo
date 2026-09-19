import 'package:flutter/material.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_remote_image.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    this.imageUrl,
    this.size = 54,
    this.radius = 14,
  });

  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? KairoRemoteImage(
                url: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: KairoColors.buttonGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.groups, color: Colors.white, size: size * 0.5),
    );
  }
}
