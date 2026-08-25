import 'package:flutter/material.dart';

abstract final class ResponsiveBreakpoints {
  static const double desktop = 768;
  /// Mismo incremento (+8) que las tarjetas de historias del feed.
  static const double feedStorySizeBoost = 8;
  static const double feedCardMaxWidth = 450 + feedStorySizeBoost;
  static const double feedStoryCardWidth = 68 + feedStorySizeBoost;
  static const double feedStoryCardHeight = 84 + feedStorySizeBoost + 10;

  static const double feedWebMediaAspect = 9 / 16;
  static const double feedWebViewportHeightFactor = 0.82;

  static const double feedHeaderBarHeight = 40;
  static const double feedStoriesHeight = feedStoryCardHeight;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// Usa el ancho real del padre (evita falsos positivos en web con ventana ancha).
  static bool isDesktopWidth(double width) {
    if (!width.isFinite) return false;
    return width >= desktop;
  }

  static double? feedWebMediaHeight(BuildContext context, double cardWidth) {
    if (!isDesktop(context)) return null;
    final natural = cardWidth / feedWebMediaAspect;
    final max = MediaQuery.sizeOf(context).height * feedWebViewportHeightFactor;
    return natural < max ? natural : max;
  }
}

/// Solo limita ancho en escritorio según el espacio real del padre.
class FeedCardConstraint extends StatelessWidget {
  const FeedCardConstraint({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!ResponsiveBreakpoints.isDesktopWidth(constraints.maxWidth)) {
          return SizedBox(width: double.infinity, child: child);
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ResponsiveBreakpoints.feedCardMaxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
