import 'package:flutter/material.dart';
import '../theme/kairo_colors.dart';
import 'kairo_remote_image.dart';

class KairoAvatar extends StatelessWidget {
  const KairoAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.onTap,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    final initial = (name != null && name!.trim().isNotEmpty) ? name!.trim()[0].toUpperCase() : '?';
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto ? null : KairoColors.logoGradient,
        color: hasPhoto ? KairoColors.darkHover : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto ? _photo(context, url, initial) : _initial(initial),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }

  Widget _initial(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, String url, String initial) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(32, 256);
    return KairoRemoteImage(
      url: url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      memCacheWidth: px,
      memCacheHeight: px,
      placeholder: (_, __) => const ColoredBox(color: KairoColors.darkHover),
      errorWidget: (_, __, ___) => _initial(initial),
    );
  }
}
