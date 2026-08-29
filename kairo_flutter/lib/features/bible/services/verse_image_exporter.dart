import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VerseImageExporter {
  VerseImageExporter._();

  static const exportSize = 1080.0;

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
    required double fontSize,
    required Color textColor,
    required TextAlign align,
    required double sourceWidth,
    String watermark = 'KAIRO',
    String? photographer,
  }) async {
    final scale = exportSize / (sourceWidth <= 0 ? 360 : sourceWidth);
    final codec = await ui.instantiateImageCodec(
      backgroundBytes,
      targetWidth: exportSize.toInt(),
    );
    final frame = await codec.getNextFrame();
    final bg = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, exportSize, exportSize));
    final dst = Size(exportSize, exportSize);

    final srcSize = Size(bg.width.toDouble(), bg.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, srcSize, dst);
    final inputRect = Alignment.center.inscribe(fitted.source, Offset.zero & srcSize);
    final outputRect = Alignment.center.inscribe(fitted.destination, Offset.zero & dst);
    canvas.drawImageRect(bg, inputRect, outputRect, Paint()..filterQuality = FilterQuality.high);

    final overlay = textColor.computeLuminance() > 0.5
        ? const Color(0x61000000)
        : const Color(0x47FFFFFF);
    canvas.drawRect(Offset.zero & dst, Paint()..color = overlay);

    final padding = 22 * scale;
    final maxWidth = exportSize - padding * 2;
    final versePainter = TextPainter(
      text: TextSpan(
        text: verse,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize * scale,
          fontWeight: FontWeight.w600,
          height: 1.35,
          shadows: [
            Shadow(blurRadius: 12 * scale, color: Colors.black.withValues(alpha: 0.55)),
          ],
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    TextPainter? citationPainter;
    if (citation.isNotEmpty) {
      citationPainter = TextPainter(
        text: TextSpan(
          text: citation,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.82),
            fontSize: (fontSize * 0.62).clamp(11, 18) * scale,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(blurRadius: 8 * scale, color: Colors.black.withValues(alpha: 0.5)),
            ],
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
    }

    final gap = citationPainter == null ? 0.0 : 12 * scale;
    final blockHeight = versePainter.height + gap + (citationPainter?.height ?? 0);
    var y = (exportSize - blockHeight) / 2;

    _paintAligned(canvas, versePainter, padding, y, maxWidth, align);
    y += versePainter.height + gap;
    if (citationPainter != null) {
      _paintAligned(canvas, citationPainter, padding, y, maxWidth, align);
    }

    final markStyle = TextStyle(
      color: textColor.withValues(alpha: 0.7),
      fontSize: 11 * scale,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    );
    final mark = TextPainter(
      text: TextSpan(text: watermark, style: markStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(canvas, Offset(exportSize - padding - mark.width, exportSize - padding - mark.height));

    if (photographer != null && photographer.isNotEmpty) {
      final credit = TextPainter(
        text: TextSpan(
          text: photographer,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.55),
            fontSize: 10 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: exportSize * 0.5);
      credit.paint(canvas, Offset(padding, exportSize - padding - credit.height));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(exportSize.toInt(), exportSize.toInt());
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
