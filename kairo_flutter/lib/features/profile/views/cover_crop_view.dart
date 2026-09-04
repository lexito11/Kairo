import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/kairo_colors.dart';

Future<Uint8List?> showCoverCropper(BuildContext context, Uint8List bytes) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => CoverCropView(bytes: bytes),
      fullscreenDialog: true,
    ),
  );
}

class CoverCropView extends StatefulWidget {
  const CoverCropView({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<CoverCropView> createState() => _CoverCropViewState();
}

class _CoverCropViewState extends State<CoverCropView> {
  final _boundaryKey = GlobalKey();
  final _transform = TransformationController();
  ui.Image? _decoded;
  bool _confirming = false;
  bool _didCenter = false;
  int _turns = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _decoded?.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _decoded = frame.image);
  }

  Size _displaySize(double cropW, double cropH) {
    final image = _decoded!;
    final srcW = _turns.isOdd ? image.height.toDouble() : image.width.toDouble();
    final srcH = _turns.isOdd ? image.width.toDouble() : image.height.toDouble();
    final cover = math.max(cropW / srcW, cropH / srcH);
    return Size(srcW * cover, srcH * cover);
  }

  void _centerImage(double cropW, double cropH) {
    if (_decoded == null) return;
    final size = _displaySize(cropW, cropH);
    _transform.value = Matrix4.identity()
      ..translate((cropW - size.width) / 2, (cropH - size.height) / 2);
    _didCenter = true;
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted) return;
      Navigator.pop(context, data?.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final cropW = screen.width;
    final cropH = (screen.width / 2.15).clamp(170.0, 260.0);
    final image = _decoded;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirming ? null : () => Navigator.pop(context),
        ),
        title: const Text('Ajustar portada', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _confirming || image == null ? null : _confirm,
            child: const Text('Usar', style: TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: image == null
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary400))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.black),
                      Center(
                        child: SizedBox(
                          width: cropW,
                          height: cropH,
                          child: ClipRect(
                            child: RepaintBoundary(
                              key: _boundaryKey,
                              child: ColoredBox(
                                color: Colors.black,
                                child: InteractiveViewer(
                                  transformationController: _transform,
                                  constrained: false,
                                  minScale: 1,
                                  maxScale: 5,
                                  boundaryMargin: const EdgeInsets.all(120),
                                  child: Builder(
                                    builder: (context) {
                                      final size = _displaySize(cropW, cropH);
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (!_didCenter) _centerImage(cropW, cropH);
                                      });
                                      return RotatedBox(
                                        quarterTurns: _turns,
                                        child: Image.memory(
                                          widget.bytes,
                                          width: size.width,
                                          height: size.height,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _CoverDimPainter(cropW: cropW, cropH: cropH),
                        ),
                      ),
                      Center(
                        child: IgnorePointer(
                          child: Container(
                            width: cropW,
                            height: cropH,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
                  child: Text(
                    'Mueve y pellizca para elegir qué parte se ve en la portada. No se recorta sola.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, height: 1.35),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _confirming
                            ? null
                            : () {
                                setState(() {
                                  _turns = (_turns + 1) % 4;
                                  _didCenter = false;
                                });
                                _transform.value = Matrix4.identity();
                              },
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.rotate_90_degrees_ccw, size: 18),
                        label: const Text('Girar'),
                      ),
                      TextButton.icon(
                        onPressed: _confirming
                            ? null
                            : () {
                                setState(() => _didCenter = false);
                                _centerImage(cropW, cropH);
                              },
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Reset'),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _confirming ? null : _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KairoColors.primary500,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _confirming
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Usar recorte', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CoverDimPainter extends CustomPainter {
  _CoverDimPainter({required this.cropW, required this.cropH});

  final double cropW;
  final double cropH;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cropW,
      height: cropH,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(hole);
    canvas.drawPath(path, Paint()..color = const Color(0xCC000000));
  }

  @override
  bool shouldRepaint(covariant _CoverDimPainter oldDelegate) =>
      oldDelegate.cropW != cropW || oldDelegate.cropH != cropH;
}
