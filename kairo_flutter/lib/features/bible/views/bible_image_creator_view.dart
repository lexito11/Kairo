import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../posts/providers/posts_provider.dart';
import '../models/bible_photo.dart';
import '../services/bible_photo_api.dart';
import '../services/verse_image_exporter.dart';
import '../widgets/bible_chrome.dart';

class BibleImageCreatorView extends StatefulWidget {
  const BibleImageCreatorView({
    super.key,
    this.initialText = '',
    this.initialRef = '',
  });

  final String initialText;
  final String initialRef;

  @override
  State<BibleImageCreatorView> createState() => _BibleImageCreatorViewState();
}

class _BibleImageCreatorViewState extends State<BibleImageCreatorView> {
  static const _maxChars = 280;
  static const _categoryIcons = {
    BiblePhotoCategory.nature: Icons.forest_outlined,
    BiblePhotoCategory.sky: Icons.wb_twilight_outlined,
    BiblePhotoCategory.mountains: Icons.terrain_outlined,
    BiblePhotoCategory.abstractArt: Icons.blur_on_outlined,
    BiblePhotoCategory.landscapes: Icons.landscape_outlined,
  };

  final _canvasKey = GlobalKey();
  late final TextEditingController _text;
  late final TextEditingController _ref;

  BiblePhotoCategory _category = BiblePhotoCategory.nature;
  List<BiblePhoto> _photos = const [];
  BiblePhoto? _selected;
  bool _loadingPhotos = true;
  String? _photosError;

  double _fontSize = 20;
  TextAlign _align = TextAlign.center;
  Color _textColor = Colors.white;
  String _fontId = 'sans';
  VerseTextFill _fill = VerseTextFill.none;
  bool _stroke = false;

  bool _publishing = false;
  Uint8List? _renderedImageBytes;

  static const _palette = [
    Colors.white,
    Color(0xFF111111),
    Color(0xFFF5E6C8),
    Color(0xFFFBBF24),
    Color(0xFF38BDF8),
    Color(0xFFF472B6),
    Color(0xFF4ADE80),
    Color(0xFFF87171),
  ];

  VerseTextLook get _look => VerseTextLook(
        color: _textColor,
        align: _align,
        fontSize: _fontSize,
        fontId: _fontId,
        fill: _fill,
        stroke: _stroke,
      );

  String get _citation {
    final raw = _ref.text.trim();
    if (raw.isEmpty) return '';
    final upper = raw.toUpperCase();
    if (upper.contains('RVR09') || upper.contains('RVR')) return raw;
    return '$raw - RVR09';
  }

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    _ref = TextEditingController(text: widget.initialRef);
    _text.addListener(() => setState(() {}));
    _ref.addListener(() => setState(() {}));
    _loadPhotos();
  }

  @override
  void dispose() {
    _text.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos({bool force = false}) async {
    setState(() {
      _loadingPhotos = true;
      _photosError = null;
    });
    try {
      final photos = await BiblePhotoApi.instance.fetch(_category, force: force);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _loadingPhotos = false;
        _selected ??= photos.isEmpty ? null : photos.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _photosError = 'No se pudieron cargar los fondos.';
        _loadingPhotos = false;
      });
    }
  }

  Future<void> _selectPhoto(BiblePhoto photo) async {
    setState(() => _selected = photo);
    await BiblePhotoApi.instance.trackDownload(photo);
  }

  Future<void> _selectCategory(BiblePhotoCategory category) async {
    if (_category == category && _photos.isNotEmpty) return;
    setState(() => _category = category);
    await _loadPhotos();
  }

  Future<Uint8List> _renderCanvasFile() async {
    final photo = _selected;
    if (photo == null) throw Exception('Elige un fondo primero');
    final verse = _text.text.trim().isEmpty ? 'Tu versículo o mensaje aquí...' : _text.text.trim();
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final sourceWidth = box?.size.width ?? 360;

    try {
      final bgBytes = await VerseImageExporter.downloadBytes(photo.fullUrl);
      return VerseImageExporter.render(
        backgroundBytes: bgBytes,
        verse: verse,
        citation: _citation,
        look: _look,
        sourceWidth: sourceWidth,
        photographer: photo.photographer,
      );
    } catch (_) {
      return _captureWidget();
    }
  }

  Future<Uint8List> _captureWidget() async {
    final ctx = _canvasKey.currentContext;
    if (ctx == null) throw Exception('El lienzo no está listo');
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('El lienzo no está listo');
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw Exception('No se pudo capturar el lienzo');
    return data.buffer.asUint8List();
  }

  Future<void> _publish() async {
    if (!AuthService().isSignedIn) {
      context.push('/auth/signin');
      return;
    }
    final verse = _text.text.trim();
    if (verse.isEmpty || _selected == null) return;
    setState(() => _publishing = true);
    try {
      final bytes = await _renderCanvasFile();
      if (!mounted) return;
      setState(() => _renderedImageBytes = bytes);

      final content = _citation.isEmpty ? verse : '$verse\n\n$_citation';
      await context.read<PostsProvider>().createPost(
            content: content,
            postKind: PostKind.testimony,
            files: [
              (bytes: bytes, name: 'kairo-versiculo.png', mime: 'image/png'),
            ],
          );
      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      child: Column(
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: _canvas(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                _styleControls(),
                const SizedBox(height: 18),
                const Text(
                  'ELIGE UN FONDO',
                  style: TextStyle(
                    color: KairoColors.darkTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                _categoryChips(),
                const SizedBox(height: 12),
                _photoCarousel(),
                const SizedBox(height: 20),
                const Text(
                  'VERSÍCULO O MENSAJE',
                  style: TextStyle(
                    color: KairoColors.darkTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                _verseFields(),
                const SizedBox(height: 16),
                _publishButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 16, 8),
      child: const Row(
        children: [
          BibleBackButton(),
          SizedBox(width: 8),
          Icon(Icons.photo_outlined, color: KairoColors.primary400, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Biblia', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Crea tu imagen', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    final verse = _text.text.trim().isEmpty ? 'Tu versículo o mensaje aquí...' : _text.text.trim();
    final photo = _selected;
    final look = _look;
    final height = (MediaQuery.sizeOf(context).height * 0.36).clamp(280.0, 380.0);
    return Center(
      child: SizedBox(
        height: height,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: RepaintBoundary(
            key: _canvasKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photo == null)
                    const ColoredBox(color: KairoColors.darkCard)
                  else
                    Image.network(
                      photo.fullUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: KairoColors.darkCard),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const ColoredBox(
                          color: KairoColors.darkCard,
                          child: Center(
                            child: CircularProgressIndicator(color: KairoColors.primary500, strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ColoredBox(
                    color: look.color.computeLuminance() > 0.5
                        ? const Color(0x59000000)
                        : const Color(0x3DFFFFFF),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 36),
                    child: Center(child: _verseBlock(verse, look)),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 8,
                    child: Text(
                      'KAIRO',
                      style: TextStyle(
                        color: look.color.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (photo != null)
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Text(
                        photo.photographer,
                        style: TextStyle(
                          color: look.color.withValues(alpha: 0.55),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _verseBlock(String verse, VerseTextLook look) {
    final placeholder = _text.text.trim().isEmpty;
    Widget textColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (look.align) {
        TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
        TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.center,
      },
      children: [
        _outlinedText(
          verse,
          look.verseStyle(placeholder: placeholder),
          look,
        ),
        if (_citation.isNotEmpty) ...[
          const SizedBox(height: 10),
          _outlinedText(_citation, look.citationStyle(), look),
        ],
      ],
    );
    if (look.fill != VerseTextFill.none) {
      textColumn = DecoratedBox(
        decoration: BoxDecoration(
          color: look.fillColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: textColumn,
        ),
      );
    }
    return textColumn;
  }

  Widget _outlinedText(String value, TextStyle style, VerseTextLook look) {
    final text = Text(
      value,
      textAlign: look.align,
      softWrap: true,
      style: style,
    );
    if (!look.stroke) return text;
    return Stack(
      children: [
        Text(
          value,
          textAlign: look.align,
          softWrap: true,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = look.strokeColor,
            color: null,
            shadows: const [],
          ),
        ),
        text,
      ],
    );
  }

  Widget _styleControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Aa', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  activeColor: KairoColors.primary500,
                  inactiveColor: KairoColors.darkHover,
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              Text(
                '${_fontSize.round()}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _palette.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final color = _palette[i];
                final selected = color == _textColor;
                return GestureDetector(
                  onTap: () => setState(() => _textColor = color),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? KairoColors.primary400 : Colors.white24,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FontChip(label: 'Sans', selected: _fontId == 'sans', onTap: () => setState(() => _fontId = 'sans')),
              const SizedBox(width: 6),
              _FontChip(label: 'Serif', selected: _fontId == 'serif', onTap: () => setState(() => _fontId = 'serif')),
              const SizedBox(width: 6),
              _FontChip(label: 'Elegante', selected: _fontId == 'script', onTap: () => setState(() => _fontId = 'script')),
              const Spacer(),
              _AlignButton(
                icon: Icons.format_align_left,
                selected: _align == TextAlign.left,
                onTap: () => setState(() => _align = TextAlign.left),
              ),
              const SizedBox(width: 6),
              _AlignButton(
                icon: Icons.format_align_center,
                selected: _align == TextAlign.center,
                onTap: () => setState(() => _align = TextAlign.center),
              ),
              const SizedBox(width: 6),
              _AlignButton(
                icon: Icons.format_align_right,
                selected: _align == TextAlign.right,
                onTap: () => setState(() => _align = TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  selected: _fill == VerseTextFill.none,
                  label: 'Sin fondo',
                  onTap: () => setState(() => _fill = VerseTextFill.none),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ToggleChip(
                  selected: _fill == VerseTextFill.dark,
                  label: 'Fondo oscuro',
                  onTap: () => setState(() => _fill = VerseTextFill.dark),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ToggleChip(
                  selected: _fill == VerseTextFill.light,
                  label: 'Fondo claro',
                  onTap: () => setState(() => _fill = VerseTextFill.light),
                ),
              ),
              const SizedBox(width: 6),
              _AlignButton(
                icon: Icons.border_color_outlined,
                selected: _stroke,
                onTap: () => setState(() => _stroke = !_stroke),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BiblePhotoCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = BiblePhotoCategory.values[i];
          final selected = category == _category;
          return GestureDetector(
            onTap: () => _selectCategory(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? KairoColors.primary700 : KairoColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? KairoColors.primary400 : KairoColors.darkBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(_categoryIcons[category], size: 16, color: selected ? Colors.white : KairoColors.darkTextSecondary),
                  const SizedBox(width: 6),
                  Text(
                    category.label,
                    style: TextStyle(
                      color: selected ? Colors.white : KairoColors.darkTextSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _photoCarousel() {
    if (_loadingPhotos) {
      return SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => const SizedBox(
            width: 128,
            height: 92,
            child: BibleSkeletonBox(height: 92, borderRadius: 12),
          ),
        ),
      );
    }
    if (_photosError != null) {
      return Container(
        height: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: KairoColors.darkCard, borderRadius: BorderRadius.circular(12)),
        child: TextButton(
          onPressed: () => _loadPhotos(force: true),
          child: Text(_photosError!, style: const TextStyle(color: KairoColors.darkTextSecondary)),
        ),
      );
    }
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final photo = _photos[i];
          final selected = photo.id == _selected?.id;
          return GestureDetector(
            onTap: () => _selectPhoto(photo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? KairoColors.primary400 : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(photo.thumbUrl, fit: BoxFit.cover),
                    if (selected)
                      const ColoredBox(
                        color: Color(0x33000000),
                        child: Icon(Icons.check_circle, color: Colors.white, size: 26),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _verseFields() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: KairoColors.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(
            children: [
              TextField(
                controller: _text,
                maxLength: _maxChars,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, height: 1.4),
                cursorColor: KairoColors.primary500,
                decoration: const InputDecoration(
                  hintText: 'Escribe o pega un versículo...',
                  hintStyle: TextStyle(color: KairoColors.darkTextSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_text.text.length}/$_maxChars',
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: KairoColors.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _ref,
            style: const TextStyle(color: Colors.white),
            cursorColor: KairoColors.primary500,
            decoration: const InputDecoration(
              hintText: 'Referencia Ej: Génesis 1:1',
              hintStyle: TextStyle(color: KairoColors.darkTextSecondary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _publishButton() {
    final disabled = _publishing || _text.text.trim().isEmpty || _selected == null;
    return GestureDetector(
      onTap: disabled ? null : _publish,
      child: Opacity(
        opacity: disabled && !_publishing ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: KairoColors.primary700,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_publishing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                _renderedImageBytes != null && _publishing ? 'Subiendo imagen...' : 'Publicar en el Feed',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KairoColors.primary700 : KairoColors.darkHover,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : KairoColors.darkTextSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.selected, required this.label, required this.onTap});

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? KairoColors.primary700 : KairoColors.darkHover,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : KairoColors.darkTextSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _AlignButton extends StatelessWidget {
  const _AlignButton({required this.icon, required this.selected, required this.onTap});

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? KairoColors.primary700 : KairoColors.darkHover,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: selected ? Colors.white : KairoColors.darkTextSecondary),
      ),
    );
  }
}
