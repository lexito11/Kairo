import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/theme/kairo_layout.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../auth/widgets/gradient_button.dart';

class DraftMedia {
  DraftMedia({
    required this.bytes,
    required this.name,
    required this.mime,
    this.path,
  });

  Uint8List bytes;
  final String name;
  final String mime;
  final String? path;

  bool get isVideo => mime.startsWith('video/');

  ({Uint8List bytes, String name, String mime}) get asUpload =>
      (bytes: bytes, name: name, mime: isVideo ? mime : 'image/png');
}

Future<List<DraftMedia>?> showMediaReview({
  required BuildContext context,
  required List<DraftMedia> items,
  required PostKind postKind,
  required String caption,
  String? authorName,
  String? authorImage,
}) {
  return Navigator.of(context).push<List<DraftMedia>>(
    MaterialPageRoute(
      builder: (_) => MediaReviewView(
        items: items,
        postKind: postKind,
        caption: caption,
        authorName: authorName,
        authorImage: authorImage,
      ),
    ),
  );
}

class MediaReviewView extends StatefulWidget {
  const MediaReviewView({
    super.key,
    required this.items,
    required this.postKind,
    required this.caption,
    this.authorName,
    this.authorImage,
  });

  final List<DraftMedia> items;
  final PostKind postKind;
  final String caption;
  final String? authorName;
  final String? authorImage;

  @override
  State<MediaReviewView> createState() => _MediaReviewViewState();
}

class _MediaReviewViewState extends State<MediaReviewView> {
  late final List<DraftMedia> _items;
  late final List<int> _turns;
  late final List<int> _cropResetTicks;
  late final List<TransformationController> _zooms;
  final _previewKeys = <GlobalKey>[];
  final _page = PageController();
  int _index = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List<DraftMedia>.from(widget.items);
    _turns = List<int>.filled(_items.length, 0, growable: true);
    _cropResetTicks = List<int>.filled(_items.length, 0, growable: true);
    _zooms = [for (var i = 0; i < _items.length; i++) TransformationController()];
    _previewKeys.addAll([for (var i = 0; i < _items.length; i++) GlobalKey()]);
  }

  @override
  void dispose() {
    _page.dispose();
    for (final z in _zooms) {
      z.dispose();
    }
    super.dispose();
  }

  DraftMedia get _current => _items[_index];

  void _rotate() {
    if (_current.isVideo) return;
    _zooms[_index].value = Matrix4.identity();
    setState(() {
      _turns[_index] = (_turns[_index] + 1) % 4;
      _cropResetTicks[_index]++;
    });
  }

  void _resetAdjust() {
    _zooms[_index].value = Matrix4.identity();
    setState(() {
      _turns[_index] = 0;
      _cropResetTicks[_index]++;
    });
  }

  void _removeCurrent() {
    if (_items.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _items.removeAt(_index);
      _turns.removeAt(_index);
      _cropResetTicks.removeAt(_index);
      _zooms.removeAt(_index).dispose();
      _previewKeys.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].isVideo) continue;
        final captured = await _captureFrame(i);
        if (captured != null) {
          _items[i].bytes = captured;
          _turns[i] = 0;
          _zooms[i].value = Matrix4.identity();
        }
      }
      if (!mounted) return;
      Navigator.pop(context, _items);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List?> _captureFrame(int i) async {
    final ctx = _previewKeys[i].currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    try {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.authorName?.trim().isNotEmpty == true ? widget.authorName! : 'Tú';
    final caption = widget.caption.trim();
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        title: const Text('Revisar publicación', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _confirm,
            child: const Text('Usar', style: TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _page,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final item = _items[i];
                if (item.isVideo) {
                  return ColoredBox(
                    color: KairoColors.darkBg,
                    child: _VideoPreview(path: item.path),
                  );
                }
                return const ColoredBox(color: KairoColors.darkBg);
              },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    _current.isVideo
                        ? 'Pulsa para reproducir y confirma que es el video correcto.'
                        : 'Pellizca y mueve para recortar la parte que quieres. Gira si hace falta.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                  ),
                ),
                if (_items.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_index + 1} / ${_items.length}',
                      style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      if (!_current.isVideo)
                        _ToolChip(icon: Icons.rotate_90_degrees_ccw, label: 'Girar', onTap: _rotate),
                      if (!_current.isVideo) ...[
                        const SizedBox(width: 8),
                        _ToolChip(icon: Icons.restart_alt, label: 'Reset', onTap: _resetAdjust),
                      ],
                      const Spacer(),
                      _ToolChip(icon: Icons.delete_outline, label: 'Quitar', onTap: _removeCurrent, danger: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Así se verá tu publicación',
                        style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 10),
                      if (widget.postKind == PostKind.testimony)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Testimonio', style: TextStyle(color: KairoColors.primary400, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      Row(
                        children: [
                          KairoAvatar(imageUrl: widget.authorImage, name: name, size: 32),
                          const SizedBox(width: 8),
                          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(caption, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                      ],
                      if (!_current.isVideo) ...[
                        const SizedBox(height: 10),
                        AspectRatio(
                          aspectRatio: KairoLayout.feedImageAspectRatio,
                          child: _FeedImageCropBox(
                            boundaryKey: _previewKeys[_index],
                            bytes: _current.bytes,
                            turns: _turns[_index],
                            zoom: _zooms[_index],
                            resetTick: _cropResetTicks[_index],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: GradientButton(
                    label: _saving ? 'Preparando...' : 'Usar en la publicación',
                    loading: _saving,
                    onPressed: _confirm,
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

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? KairoColors.errorText : Colors.white;
    return Material(
      color: danger ? KairoColors.darkCard : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedImageCropBox extends StatefulWidget {
  const _FeedImageCropBox({
    required this.boundaryKey,
    required this.bytes,
    required this.turns,
    required this.zoom,
    required this.resetTick,
  });

  final GlobalKey boundaryKey;
  final Uint8List bytes;
  final int turns;
  final TransformationController zoom;
  final int resetTick;

  @override
  State<_FeedImageCropBox> createState() => _FeedImageCropBoxState();
}

class _FeedImageCropBoxState extends State<_FeedImageCropBox> {
  ui.Image? _decoded;
  bool _didCenter = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _FeedImageCropBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      _decoded?.dispose();
      _decoded = null;
      _didCenter = false;
      _decode();
      return;
    }
    if (oldWidget.resetTick != widget.resetTick || oldWidget.turns != widget.turns) {
      _didCenter = false;
    }
  }

  @override
  void dispose() {
    _decoded?.dispose();
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
    final srcW = widget.turns.isOdd ? image.height.toDouble() : image.width.toDouble();
    final srcH = widget.turns.isOdd ? image.width.toDouble() : image.height.toDouble();
    final cover = math.max(cropW / srcW, cropH / srcH);
    return Size(srcW * cover, srcH * cover);
  }

  void _center(double cropW, double cropH) {
    if (_decoded == null) return;
    final size = _displaySize(cropW, cropH);
    widget.zoom.value = Matrix4.identity()
      ..translate((cropW - size.width) / 2, (cropH - size.height) / 2);
    _didCenter = true;
  }

  @override
  Widget build(BuildContext context) {
    if (_decoded == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary400),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cropW = constraints.maxWidth;
        final cropH = constraints.maxHeight;
        if (!_didCenter && cropW.isFinite && cropH.isFinite && cropW > 0 && cropH > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_didCenter) {
              _center(cropW, cropH);
              if (mounted) setState(() {});
            }
          });
        }
        final size = _displaySize(cropW, cropH);
        return ClipRect(
          child: RepaintBoundary(
            key: widget.boundaryKey,
            child: InteractiveViewer(
              transformationController: widget.zoom,
              constrained: false,
              minScale: 1,
              maxScale: 5,
              boundaryMargin: const EdgeInsets.all(80),
              child: RotatedBox(
                quarterTurns: widget.turns,
                child: Image.memory(
                  widget.bytes,
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({this.path});

  final String? path;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final path = widget.path;
    if (path == null || path.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    try {
      final uri = Uri.tryParse(path);
      final canNetwork = path.startsWith('blob:') || path.startsWith('http') || path.startsWith('data:') || kIsWeb;
      final controller = canNetwork && uri != null
          ? VideoPlayerController.networkUrl(uri)
          : VideoPlayerController.networkUrl(Uri.file(path));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed || c == null || !c.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, color: Colors.white70, size: 48),
            SizedBox(height: 8),
            Text('Video seleccionado', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
        ],
      ),
    );
  }
}
