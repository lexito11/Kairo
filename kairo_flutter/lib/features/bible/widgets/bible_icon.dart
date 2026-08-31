import 'package:flutter/material.dart';

/// Biblia en trazo simple: libro cerrado con cruz.
class BibleIcon extends StatelessWidget {
  const BibleIcon({
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth,
  });

  final double size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BibleIconPainter(
          color: resolved,
          strokeWidth: strokeWidth ?? (size * 0.075).clamp(1.4, 2.1),
        ),
      ),
    );
  }
}

class _BibleIconPainter extends CustomPainter {
  const _BibleIconPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    final book = RRect.fromLTRBR(
      w * 0.20,
      h * 0.10,
      w * 0.80,
      h * 0.90,
      Radius.circular(w * 0.09),
    );
    canvas.drawRRect(book, stroke);

    canvas.drawLine(
      Offset(w * 0.34, h * 0.18),
      Offset(w * 0.34, h * 0.82),
      stroke,
    );

    final cx = w * 0.58;
    canvas.drawLine(Offset(cx, h * 0.30), Offset(cx, h * 0.66), stroke);
    canvas.drawLine(Offset(w * 0.46, h * 0.40), Offset(w * 0.70, h * 0.40), stroke);
  }

  @override
  bool shouldRepaint(covariant _BibleIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
