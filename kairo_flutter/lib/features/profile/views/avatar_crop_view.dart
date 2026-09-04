import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/kairo_colors.dart';

Future<Uint8List?> showAvatarCropper(BuildContext context, Uint8List bytes) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => AvatarCropView(bytes: bytes),
      fullscreenDialog: true,
    ),
  );
}

class AvatarCropView extends StatefulWidget {
  const AvatarCropView({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<AvatarCropView> createState() => _AvatarCropViewState();
}

class _AvatarCropViewState extends State<AvatarCropView> {
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

  void _centerImage(double cropSize) {
    final image = _decoded;
    if (image == null) return;
    final cover = cropSize / math.min(image.width, image.height);
    final displayW = image.width * cover;
    final displayH = image.height * cover;
    _transform.value = Matrix4.identity()
      ..translate((cropSize - displayW) / 2, (cropSize - displayH) / 2);
    _didCenter = true;
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final ctx = _boundaryKey.currentContext;
      final boundary = ctx?.findRenderObject();
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
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final cropSize = (shortest * 0.78).clamp(240.0, 360.0);
    final image = _decoded;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirming ? null : () => Navigator.pop(context),
        ),
        title: const Text('Ajustar foto', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _confirming || image == null ? null : _confirm,
            child: const Text(
              'Usar',
              style: TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w800),
            ),
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
                          width: cropSize,
                          height: cropSize,
                          child: ClipOval(
                            child: RepaintBoundary(
                              key: _boundaryKey,
                              child: ColoredBox(
                                color: Colors.black,
                                child: InteractiveViewer(
                                  transformationController: _transform,
                                  constrained: false,
                                  minScale: 1,
                                  maxScale: 5,
                                  boundaryMargin: const EdgeInsets.all(80),
                                  child: Builder(
                                    builder: (context) {
                                      final cover = cropSize / math.min(image.width, image.height);
                                      final displayW = image.width * cover;
                                      final displayH = image.height * cover;
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (!_didCenter) _centerImage(cropSize);
                                      });
                                      return RotatedBox(
                                        quarterTurns: _turns,
                                        child: Image.memory(
                                          widget.bytes,
                                          width: displayW,
                                          height: displayH,
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
                          painter: _CircleDimPainter(cropSize: cropSize),
                        ),
                      ),
                      Center(
                        child: IgnorePointer(
                          child: Container(
                            width: cropSize,
                            height: cropSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
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
                    'Mueve y pellizca para elegir qué parte se ve en el círculo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, height: 1.35),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    children: [
                      _CropTool(
                        icon: Icons.rotate_90_degrees_ccw,
                        label: 'Girar',
                        onTap: _confirming
                            ? null
                            : () {
                                setState(() {
                                  _turns = (_turns + 1) % 4;
                                  _didCenter = false;
                                });
                                _transform.value = Matrix4.identity();
                              },
                      ),
                      const SizedBox(width: 10),
                      _CropTool(
                        icon: Icons.restart_alt,
                        label: 'Reset',
                        onTap: _confirming
                            ? null
                            : () {
                                setState(() {
                                  _turns = 0;
                                  _didCenter = false;
                                });
                              },
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

class _CircleDimPainter extends CustomPainter {
  _CircleDimPainter({required this.cropSize});

  final double cropSize;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cropSize,
      height: cropSize,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(hole);
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xCC000000),
    );
  }

  @override
  bool shouldRepaint(covariant _CircleDimPainter oldDelegate) => oldDelegate.cropSize != cropSize;
}

class _CropTool extends StatelessWidget {
  const _CropTool({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
