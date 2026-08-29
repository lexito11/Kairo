import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum VerseTextFill { none, dark, light }

class VerseTextLook {
  const VerseTextLook({
    required this.color,
    required this.align,
    required this.fontSize,
    this.fontId = 'sans',
    this.fill = VerseTextFill.none,
    this.stroke = false,
  });

  final Color color;
  final TextAlign align;
  final double fontSize;
  final String fontId;
  final VerseTextFill fill;
  final bool stroke;

  String? get fontFamily => switch (fontId) {
        'serif' => 'serif',
        'script' => 'cursive',
        _ => null,
      };

  FontStyle get fontStyle => fontId == 'script' ? FontStyle.italic : FontStyle.normal;

  Color get strokeColor => color.computeLuminance() > 0.55 ? const Color(0xFF111111) : Colors.white;

  Color get fillColor => switch (fill) {
        VerseTextFill.dark => const Color(0xCC111111),
        VerseTextFill.light => const Color(0xD9F8FAFC),
        VerseTextFill.none => Colors.transparent,
      };

  TextStyle verseStyle({double scale = 1, bool placeholder = false}) {
    return TextStyle(
      color: color,
      fontSize: fontSize * scale,
      fontFamily: fontFamily,
      fontStyle: placeholder ? FontStyle.italic : fontStyle,
      fontWeight: FontWeight.w600,
      height: 1.35,
      shadows: fill == VerseTextFill.none
          ? [Shadow(blurRadius: 10 * scale, color: Colors.black.withValues(alpha: 0.55))]
          : const [],
    );
  }

  TextStyle citationStyle({double scale = 1}) {
    return verseStyle(scale: scale).copyWith(
      fontSize: (fontSize * 0.62).clamp(11, 16) * scale,
      color: color.withValues(alpha: 0.88),
      fontWeight: FontWeight.w600,
    );
  }
}

class VerseImageExporter {
  VerseImageExporter._();

  static const exportWidth = 1080.0;
  static const exportHeight = 1920.0;

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
    final scale = exportWidth / (sourceWidth <= 0 ? 220 : sourceWidth);
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

    final overlay = look.color.computeLuminance() > 0.5
        ? const Color(0x59000000)
        : const Color(0x3DFFFFFF);
    canvas.drawRect(Offset.zero & dst, Paint()..color = overlay);

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

    final gap = citationPainter == null ? 0.0 : 14 * scale;
    final blockHeight = versePainter.height + gap + (citationPainter?.height ?? 0);
    final blockWidth = [
      versePainter.width,
      citationPainter?.width ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    var y = (exportHeight - blockHeight) / 2;

    if (look.fill != VerseTextFill.none) {
      final rectPad = 16 * scale;
      final left = switch (look.align) {
        TextAlign.right || TextAlign.end => padding + maxWidth - blockWidth - rectPad,
        TextAlign.center || TextAlign.justify => padding + (maxWidth - blockWidth) / 2 - rectPad,
        _ => padding - rectPad,
      };
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y - rectPad, blockWidth + rectPad * 2, blockHeight + rectPad * 2),
        Radius.circular(14 * scale),
      );
      canvas.drawRRect(rrect, Paint()..color = look.fillColor);
    }

    if (look.stroke) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * scale
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
          color: look.color.withValues(alpha: 0.7),
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
            color: look.color.withValues(alpha: 0.55),
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
