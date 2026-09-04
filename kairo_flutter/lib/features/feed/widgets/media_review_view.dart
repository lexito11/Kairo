import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
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
    setState(() => _turns[_index] = (_turns[_index] + 1) % 4);
  }

  void _resetAdjust() {
    _zooms[_index].value = Matrix4.identity();
    setState(() => _turns[_index] = 0);
  }

  void _removeCurrent() {
    if (_items.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _items.removeAt(_index);
      _turns.removeAt(_index);
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
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final item = _items[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: const Color(0xFF111111),
                            child: item.isVideo
                                ? _VideoPreview(path: item.path)
                                : RepaintBoundary(
                                    key: _previewKeys[i],
                                    child: InteractiveViewer(
                                      transformationController: _zooms[i],
                                      minScale: 1,
                                      maxScale: 4,
                                      child: Center(
                                        child: RotatedBox(
                                          quarterTurns: _turns[i],
                                          child: Image.memory(item.bytes, fit: BoxFit.contain),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.isVideo ? 'Pulsa para reproducir y confirma que es el video correcto.' : 'Pellizca para ajustar el encuadre. Gira si hace falta.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 4 / 5,
                        child: _current.isVideo
                            ? const ColoredBox(
                                color: Color(0xFF111111),
                                child: Center(child: Icon(Icons.videocam, color: Colors.white70, size: 36)),
                              )
                            : RotatedBox(
                                quarterTurns: _turns[_index],
                                child: Image.memory(_current.bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
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
      color: KairoColors.darkCard,
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
