import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/kairo_colors.dart';

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
      child: hasPhoto ? _photo(url, initial) : _initial(initial),
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

  Widget _photo(String url, String initial) {
    if (kIsWeb) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _initial(initial),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => const ColoredBox(color: KairoColors.darkHover),
      errorWidget: (_, __, ___) => _initial(initial),
    );
  }
}
