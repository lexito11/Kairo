import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/kairo_layout.dart';
import '../models/bible_font.dart';

enum VerseBgStyle { none, block, tight }

class VerseTextLook {
  const VerseTextLook({
    required this.color,
    required this.strokeColor,
    required this.align,
    required this.fontSize,
    this.fontId = 'sans',
    this.strokeWidth = 0,
    this.shadow = true,
    this.opacity = 1,
    this.sizeScale = 1,
    this.letterSpacing = 0,
    this.lineHeight = 1.28,
    this.bold = true,
    this.italic = false,
    this.underline = false,
    this.bgStyle = VerseBgStyle.none,
    this.bgColor = const Color(0xFF111111),
    this.bgOpacity = 0.55,
  });

  final Color color;
  final Color strokeColor;
  final TextAlign align;
  final double fontSize;
  final String fontId;
  final double strokeWidth;
  final bool shadow;
  final double opacity;
  final double sizeScale;
  final double letterSpacing;
  final double lineHeight;
  final bool bold;
  final bool italic;
  final bool underline;
  final VerseBgStyle bgStyle;
  final Color bgColor;
  final double bgOpacity;

  FontStyle get fontStyle => italic ? FontStyle.italic : FontStyle.normal;

  FontWeight get fontWeight => bold ? FontWeight.w700 : FontWeight.w400;

  bool get hasStroke => strokeWidth > 0.35;

  bool get hasBackground => bgStyle != VerseBgStyle.none;

  Color get fillColor => color.withValues(alpha: opacity.clamp(0.15, 1));

  Color get resolvedBg => bgColor.withValues(alpha: bgOpacity.clamp(0.15, 1));

  List<Shadow> get letterShadows => shadow
      ? [Shadow(blurRadius: 8, color: strokeColor.withValues(alpha: 0.7 * opacity), offset: Offset.zero)]
      : const [];

  TextStyle verseStyle({double scale = 1, bool placeholder = false}) {
    final base = BibleFonts.textStyle(
      fontId: fontId,
      color: fillColor,
      fontSize: fontSize * sizeScale * scale,
      fontStyle: placeholder ? FontStyle.italic : fontStyle,
      weight: fontWeight,
    );
    return base.copyWith(
      height: lineHeight,
      letterSpacing: letterSpacing * scale,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      decorationColor: fillColor,
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
      fontSize: (fontSize * sizeScale * 0.62).clamp(11, 16) * scale,
      color: fillColor.withValues(alpha: (opacity * 0.92).clamp(0.15, 1)),
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
      opacity: opacity,
      sizeScale: sizeScale,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
      bold: bold,
      italic: italic,
      underline: underline,
      bgStyle: bgStyle,
      bgColor: bgColor,
      bgOpacity: bgOpacity,
    );
  }

  Size measureBlock({
    required String verse,
    required String citation,
    required double maxWidth,
  }) {
    final extra = (hasStroke ? strokeWidth : 0) + (hasBackground ? 12 : 2);
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
    return size.height <= inner.height;
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

  VerseTextLook atScale(double scale) {
    return VerseTextLook(
      color: color,
      strokeColor: strokeColor,
      align: align,
      fontSize: fontSize,
      fontId: fontId,
      strokeWidth: strokeWidth,
      shadow: shadow,
      opacity: opacity,
      sizeScale: scale,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
      bold: bold,
      italic: italic,
      underline: underline,
      bgStyle: bgStyle,
      bgColor: bgColor,
      bgOpacity: bgOpacity,
    );
  }

  double maxScaleFor({
    required String verse,
    required String citation,
    required Size inner,
    double minScale = 0.7,
    double hardMax = 1.5,
  }) {
    if (inner.width <= 0 || inner.height <= 0) return hardMax;
    if (!atScale(minScale).fitsIn(verse: verse, citation: citation, inner: inner)) {
      return minScale;
    }
    var lo = minScale;
    var hi = hardMax;
    var best = minScale;
    for (var i = 0; i < 14; i++) {
      final mid = (lo + hi) / 2;
      if (atScale(mid).fitsIn(verse: verse, citation: citation, inner: inner)) {
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

    final maxWidth = exportWidth * KairoLayout.verseColumnWidth;
    final padding = (exportWidth - maxWidth) / 2;
    final top = exportHeight * KairoLayout.verseColumnTop;
    final columnHeight = exportHeight * (1 - KairoLayout.verseColumnTop - KairoLayout.verseColumnBottom);

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
    var y = top + ((columnHeight - blockHeight) / 2).clamp(0.0, columnHeight);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(padding, top, maxWidth, columnHeight));

    if (look.hasBackground) {
      final bgPaint = Paint()..color = look.resolvedBg;
      if (look.bgStyle == VerseBgStyle.block) {
        final pad = 10 * scale;
        final blockWidth = [
          versePainter.width,
          citationPainter?.width ?? 0,
        ].reduce((a, b) => a > b ? a : b);
        final dx = switch (look.align) {
          TextAlign.right || TextAlign.end => padding + (maxWidth - blockWidth),
          TextAlign.center || TextAlign.justify => padding + (maxWidth - blockWidth) / 2,
          _ => padding,
        };
        canvas.drawRRect(
          RRect.fromLTRBR(dx - pad, y - pad, dx + blockWidth + pad, y + blockHeight + pad, Radius.circular(4 * scale)),
          bgPaint,
        );
      } else {
        _paintTightBg(canvas, versePainter, padding, y, maxWidth, look.align, bgPaint, scale);
        if (citationPainter != null) {
          _paintTightBg(canvas, citationPainter, padding, y + versePainter.height + gap, maxWidth, look.align, bgPaint, scale);
        }
      }
    }

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

    canvas.restore();

    final mark = TextPainter(
      text: TextSpan(
        text: watermark,
        style: TextStyle(
          color: Colors.white54,
          fontSize: 9 * scale,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final edge = 10.0 * scale;
    canvas.save();
    canvas.translate(exportWidth - edge - mark.width, exportHeight - edge - mark.height);
    mark.paint(canvas, Offset.zero);
    canvas.restore();

    if (photographer != null && photographer.isNotEmpty) {
      final credit = TextPainter(
        text: TextSpan(
          text: photographer,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 8 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: exportWidth * 0.45);
      canvas.save();
      canvas.translate(edge, exportHeight - edge - credit.height);
      credit.paint(canvas, Offset.zero);
      canvas.restore();
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

  static void _paintTightBg(
    Canvas canvas,
    TextPainter painter,
    double padding,
    double y,
    double maxWidth,
    TextAlign align,
    Paint paint,
    double scale,
  ) {
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => padding + (maxWidth - painter.width),
      TextAlign.center || TextAlign.justify => padding + (maxWidth - painter.width) / 2,
      _ => padding,
    };
    final inset = Offset(dx, y);
    final pad = 5 * scale;
    final length = painter.text?.toPlainText().length ?? 0;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
    );
    for (final box in boxes) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.toRect().shift(inset).inflate(pad), Radius.circular(2 * scale)),
        paint,
      );
    }
  }
}
