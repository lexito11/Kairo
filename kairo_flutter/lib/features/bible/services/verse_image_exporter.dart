import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/kairo_layout.dart';

class VerseTextLook {
  const VerseTextLook({
    required this.color,
    required this.strokeColor,
    required this.align,
    required this.fontSize,
    this.fontId = 'sans',
    this.strokeWidth = 0,
    this.shadow = true,
  });

  final Color color;
  final Color strokeColor;
  final TextAlign align;
  final double fontSize;
  final String fontId;
  final double strokeWidth;
  final bool shadow;

  String? get fontFamily => switch (fontId) {
        'serif' => 'serif',
        'script' => 'cursive',
        _ => null,
      };

  FontStyle get fontStyle => fontId == 'script' ? FontStyle.italic : FontStyle.normal;

  bool get hasStroke => strokeWidth > 0.35;

  List<Shadow> get letterShadows => shadow
      ? [Shadow(blurRadius: 6, color: Colors.black.withValues(alpha: 0.45), offset: const Offset(0, 1))]
      : const [];

  TextStyle verseStyle({double scale = 1, bool placeholder = false}) {
    return TextStyle(
      color: color,
      fontSize: fontSize * scale,
      fontFamily: fontFamily,
      fontStyle: placeholder ? FontStyle.italic : fontStyle,
      fontWeight: FontWeight.w700,
      height: 1.28,
      shadows: [
        for (final s in letterShadows)
          Shadow(
            blurRadius: s.blurRadius * scale,
            color: s.color,
            offset: Offset(s.offset.dx * scale, s.offset.dy * scale),
          ),
      ],
    );
  }

  TextStyle citationStyle({double scale = 1}) {
    return verseStyle(scale: scale).copyWith(
      fontSize: (fontSize * 0.62).clamp(11, 16) * scale,
      color: color.withValues(alpha: 0.92),
    );
  }

  VerseTextLook atSize(double size) {
    return VerseTextLook(
      color: color,
      strokeColor: strokeColor,
      align: align,
      fontSize: size,
      fontId: fontId,
      strokeWidth: strokeWidth,
      shadow: shadow,
    );
  }

  Size measureBlock({
    required String verse,
    required String citation,
    required double maxWidth,
  }) {
    final extra = (hasStroke ? strokeWidth : 0) + (shadow ? 8 : 0);
    final versePainter = TextPainter(
      text: TextSpan(text: verse, style: verseStyle()),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    var width = versePainter.width;
    var height = versePainter.height;
    if (citation.isNotEmpty) {
      final citationPainter = TextPainter(
        text: TextSpan(text: citation, style: citationStyle()),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      width = width > citationPainter.width ? width : citationPainter.width;
      height += 10 + citationPainter.height;
    }
    return Size(width + extra, height + extra);
  }

  bool fitsIn({
    required String verse,
    required String citation,
    required Size inner,
  }) {
    if (inner.width <= 0 || inner.height <= 0) return true;
    final size = measureBlock(verse: verse, citation: citation, maxWidth: inner.width);
    return size.height <= inner.height && size.width <= inner.width;
  }

  double maxSizeFor({
    required String verse,
    required String citation,
    required Size inner,
    double minSize = 12,
    double hardMax = 32,
  }) {
    if (inner.width <= 0 || inner.height <= 0) return hardMax;
    if (!atSize(minSize).fitsIn(verse: verse, citation: citation, inner: inner)) {
      return minSize;
    }
    var lo = minSize;
    var hi = hardMax;
    var best = minSize;
    for (var i = 0; i < 14; i++) {
      final mid = (lo + hi) / 2;
      if (atSize(mid).fitsIn(verse: verse, citation: citation, inner: inner)) {
        best = mid;
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return best;
  }
}

class VerseImageExporter {
  VerseImageExporter._();

  static const exportWidth = KairoLayout.feedImageExportWidth;
  static const exportHeight = KairoLayout.feedImageExportHeight;

  static Future<Uint8List> downloadBytes(String url) async {
    final res = await http
        .get(Uri.parse(url), headers: {'Accept': 'image/*'})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw Exception('No se pudo descargar el fondo');
    }
    return res.bodyBytes;
  }

  static Future<Uint8List> render({
    required Uint8List backgroundBytes,
    required String verse,
    required String citation,
    required VerseTextLook look,
    required double sourceWidth,
    String watermark = 'KAIRO',
    String? photographer,
  }) async {
    final scale = exportWidth / (sourceWidth <= 0 ? 320 : sourceWidth);
    final codec = await ui.instantiateImageCodec(
      backgroundBytes,
      targetWidth: exportWidth.toInt(),
    );
    final frame = await codec.getNextFrame();
    final bg = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, exportWidth, exportHeight));
    final dst = Size(exportWidth, exportHeight);

    final srcSize = Size(bg.width.toDouble(), bg.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, srcSize, dst);
    final inputRect = Alignment.center.inscribe(fitted.source, Offset.zero & srcSize);
    final outputRect = Alignment.center.inscribe(fitted.destination, Offset.zero & dst);
    canvas.drawImageRect(bg, inputRect, outputRect, Paint()..filterQuality = FilterQuality.high);

    final padding = 28 * scale;
    final maxWidth = exportWidth - padding * 2;

    TextSpan verseSpan(Paint? foreground) {
      final base = look.verseStyle(scale: scale);
      return TextSpan(
        text: verse,
        style: foreground == null ? base : base.copyWith(color: null, foreground: foreground, shadows: const []),
      );
    }

    TextSpan citationSpan(Paint? foreground) {
      final base = look.citationStyle(scale: scale);
      return TextSpan(
        text: citation,
        style: foreground == null ? base : base.copyWith(color: null, foreground: foreground, shadows: const []),
      );
    }

    final versePainter = TextPainter(
      text: verseSpan(null),
      textAlign: look.align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    TextPainter? citationPainter;
    if (citation.isNotEmpty) {
      citationPainter = TextPainter(
        text: citationSpan(null),
        textAlign: look.align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
    }

    final gap = citationPainter == null ? 0.0 : 12 * scale;
    final blockHeight = versePainter.height + gap + (citationPainter?.height ?? 0);
    var y = (exportHeight - blockHeight) / 2;

    if (look.hasStroke) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = look.strokeWidth * scale
        ..strokeJoin = StrokeJoin.round
        ..color = look.strokeColor;
      final verseStroke = TextPainter(
        text: verseSpan(strokePaint),
        textAlign: look.align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      _paintAligned(canvas, verseStroke, padding, y, maxWidth, look.align);
      if (citationPainter != null) {
        final citationStroke = TextPainter(
          text: citationSpan(strokePaint),
          textAlign: look.align,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);
        _paintAligned(canvas, citationStroke, padding, y + versePainter.height + gap, maxWidth, look.align);
      }
    }

    _paintAligned(canvas, versePainter, padding, y, maxWidth, look.align);
    y += versePainter.height + gap;
    if (citationPainter != null) {
      _paintAligned(canvas, citationPainter, padding, y, maxWidth, look.align);
    }

    final mark = TextPainter(
      text: TextSpan(
        text: watermark,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(canvas, Offset(exportWidth - padding - mark.width, exportHeight - padding - mark.height));

    if (photographer != null && photographer.isNotEmpty) {
      final credit = TextPainter(
        text: TextSpan(
          text: photographer,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 10 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: exportWidth * 0.5);
      credit.paint(canvas, Offset(padding, exportHeight - padding - credit.height));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(exportWidth.toInt(), exportHeight.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bg.dispose();
    image.dispose();
    picture.dispose();
    if (data == null) throw Exception('No se pudo generar la imagen');
    return data.buffer.asUint8List();
  }

  static void _paintAligned(
    Canvas canvas,
    TextPainter painter,
    double padding,
    double y,
    double maxWidth,
    TextAlign align,
  ) {
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => padding + (maxWidth - painter.width),
      TextAlign.center || TextAlign.justify => padding + (maxWidth - painter.width) / 2,
      _ => padding,
    };
    painter.paint(canvas, Offset(dx, y));
  }
}
