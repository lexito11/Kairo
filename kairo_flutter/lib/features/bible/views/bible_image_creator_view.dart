import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/theme/kairo_layout.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../posts/providers/posts_provider.dart';
import '../models/bible_photo.dart';
import '../models/bible_font.dart';
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
  double _maxFontSize = 32;
  static const _minFontSize = 12.0;
  static const _hardMaxFontSize = 48.0;
  TextAlign _align = TextAlign.center;
  Color _textColor = Colors.white;
  Color _strokeColor = const Color(0xFF111111);
  double _strokeWidth = 0;
  String _fontId = 'sans';
  bool _shadow = true;
  double _opacity = 1;
  double _sizeScale = 1;
  double _maxSizeScale = 1.5;
  static const _minScale = 0.7;
  static const _hardMaxScale = 1.5;
  double _letterSpacing = 0;
  double _lineHeight = 1.28;
  bool _bold = true;
  bool _italic = false;
  bool _underline = false;
  VerseBgStyle _bgStyle = VerseBgStyle.none;
  _EditorMainTab _mainTab = _EditorMainTab.styles;
  _StyleSubTab _styleTab = _StyleSubTab.text;

  bool _publishing = false;
  Uint8List? _renderedImageBytes;
  bool _atTextLimit = false;
  DateTime? _lastLimitWarn;

  static const _palette = [
    Colors.white,
    Color(0xFFF8FAFC),
    Color(0xFFE2E8F0),
    Color(0xFF111111),
    Color(0xFF334155),
    Color(0xFFF5E6C8),
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
    Color(0xFFFB7185),
    Color(0xFFEF4444),
    Color(0xFFF472B6),
    Color(0xFFA855F7),
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
    Color(0xFF2DD4BF),
    Color(0xFF4ADE80),
    Color(0xFF22C55E),
    Color(0xFFF97316),
  ];

  VerseTextLook get _look => VerseTextLook(
        color: _textColor,
        strokeColor: _strokeColor,
        align: _align,
        fontSize: _fontSize,
        fontId: _fontId,
        strokeWidth: _strokeWidth,
        shadow: _shadow,
        opacity: _opacity,
        sizeScale: _sizeScale,
        letterSpacing: _letterSpacing,
        lineHeight: _lineHeight,
        bold: _bold,
        italic: _italic,
        underline: _underline,
        bgStyle: _bgStyle,
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
    _text.addListener(_onCopyChanged);
    _ref.addListener(_onCopyChanged);
    _loadPhotos();
  }

  void _onCopyChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _limitFontToCanvas());
  }

  void _limitFontToCanvas() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final inner = Size(
      (box.size.width * KairoLayout.verseColumnWidth).clamp(1.0, box.size.width),
      (box.size.height * (1 - KairoLayout.verseColumnTop - KairoLayout.verseColumnBottom) - 24).clamp(1.0, box.size.height),
    );
    final verse = _text.text.trim().isEmpty ? 'Tu versículo o mensaje aquí...' : _text.text.trim();
    final maxSize = _look.maxSizeFor(
      verse: verse,
      citation: _citation,
      inner: inner,
      minSize: _minFontSize,
      hardMax: _hardMaxFontSize,
    );
    final maxScale = _look.maxScaleFor(
      verse: verse,
      citation: _citation,
      inner: inner,
      minScale: _minScale,
      hardMax: _hardMaxScale,
    );
    final hitLimit = (_fontSize >= maxSize - 0.15 && maxSize < _hardMaxFontSize - 0.4) ||
        (_sizeScale >= maxScale - 0.02 && maxScale < _hardMaxScale - 0.03);
    if ((maxSize - _maxFontSize).abs() < 0.2 &&
        _fontSize <= maxSize + 0.2 &&
        (maxScale - _maxSizeScale).abs() < 0.02 &&
        _sizeScale <= maxScale + 0.02 &&
        _atTextLimit == hitLimit) {
      return;
    }
    if (!mounted) return;
    final grewPast = _fontSize > maxSize + 0.2 || _sizeScale > maxScale + 0.02;
    setState(() {
      _maxFontSize = maxSize;
      if (_fontSize > _maxFontSize) _fontSize = _maxFontSize;
      if (_fontSize < _minFontSize) _fontSize = _minFontSize;
      _maxSizeScale = maxScale;
      if (_sizeScale > _maxSizeScale) _sizeScale = _maxSizeScale;
      if (_sizeScale < _minScale) _sizeScale = _minScale;
      _atTextLimit = hitLimit;
    });
    if (grewPast || hitLimit) _notifyTextLimit();
  }

  void _notifyTextLimit() {
    final now = DateTime.now();
    if (_lastLimitWarn != null && now.difference(_lastLimitWarn!) < const Duration(seconds: 3)) return;
    _lastLimitWarn = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El texto ya no cabe más en la imagen'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _text.removeListener(_onCopyChanged);
    _ref.removeListener(_onCopyChanged);
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _canvas(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _compactVerseBar(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                _categoryChips(),
                const SizedBox(height: 8),
                _photoCarousel(),
              ],
            ),
          ),
          Expanded(child: _editorSheet()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: _publishButton(),
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
    final maxW = (MediaQuery.sizeOf(context).width - 32).clamp(260.0, 420.0);
    final maxH = MediaQuery.sizeOf(context).height * 0.30;
    WidgetsBinding.instance.addPostFrameCallback((_) => _limitFontToCanvas());
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: AspectRatio(
          aspectRatio: KairoLayout.feedImageAspectRatio,
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth * ((1 - KairoLayout.verseColumnWidth) / 2);
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          side,
                          constraints.maxHeight * KairoLayout.verseColumnTop,
                          side,
                          constraints.maxHeight * KairoLayout.verseColumnBottom,
                        ),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return ClipRect(
                              child: Align(
                                alignment: Alignment.center,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: box.maxWidth,
                                    maxHeight: box.maxHeight,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: box.maxWidth,
                                      child: _verseBlock(verse, look),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 4,
                    bottom: 3,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 0.7, sigmaY: 0.7),
                      child: Text(
                        'KAIRO',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  if (photo != null)
                    Positioned(
                      left: 4,
                      bottom: 3,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 0.7, sigmaY: 0.7),
                        child: Text(
                          photo.photographer,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
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
    final cross = switch (look.align) {
      TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    final verseStyle = look.verseStyle(placeholder: placeholder);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        _styledLine(verse, verseStyle, look),
        if (_citation.isNotEmpty) ...[
          const SizedBox(height: 10),
          _styledLine(_citation, look.citationStyle(), look),
        ],
      ],
    );
    if (look.bgStyle != VerseBgStyle.block) return column;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: look.resolvedBg,
      child: column,
    );
  }

  Widget _styledLine(String value, TextStyle style, VerseTextLook look) {
    final text = _outlinedText(value, style, look);
    if (look.bgStyle != VerseBgStyle.tight) return text;
    return _TightLineBackground(value: value, style: style, look: look, child: text);
  }

  Widget _outlinedText(String value, TextStyle style, VerseTextLook look) {
    final text = Text(
      value,
      textAlign: look.align,
      softWrap: true,
      overflow: TextOverflow.clip,
      style: style,
    );
    if (!look.hasStroke) return text;
    return Stack(
      children: [
        Text(
          value,
          textAlign: look.align,
          softWrap: true,
          overflow: TextOverflow.clip,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = look.strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = look.strokeColor,
            color: null,
            shadows: const [],
          ),
        ),
        text,
      ],
    );
  }

  Widget _compactVerseBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          TextField(
            controller: _text,
            maxLength: _maxChars,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: KairoColors.primary400,
            decoration: const InputDecoration(
              hintText: 'Introducir texto',
              hintStyle: TextStyle(color: KairoColors.darkTextSecondary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              isDense: true,
            ),
          ),
          TextField(
            controller: _ref,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            cursorColor: KairoColors.primary400,
            decoration: const InputDecoration(
              hintText: 'Referencia Ej: Génesis 1:1',
              hintStyle: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorSheet() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF141414),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: KairoColors.darkBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _sizeSlider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                _MainTab(
                  label: 'Fuentes',
                  selected: false,
                  onTap: _openFontsWindow,
                ),
                const SizedBox(width: 22),
                _MainTab(
                  label: 'Estilos',
                  selected: _mainTab == _EditorMainTab.styles,
                  onTap: () => setState(() => _mainTab = _EditorMainTab.styles),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _stylesBody(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFontsWindow() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.65,
            width: 480,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Fuentes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _fontsGrid(onPick: (id) => Navigator.of(ctx).pop(id))),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() => _mainTab = _EditorMainTab.styles);
  }

  Widget _fontsGrid({required ValueChanged<String> onPick}) {
    return GridView.builder(
      itemCount: BibleFonts.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, i) {
        final font = BibleFonts.all[i];
        return GestureDetector(
          onTap: () {
            setState(() => _fontId = font.id);
            onPick(font.id);
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              font.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BibleFonts.textStyle(
                fontId: font.id,
                color: Colors.white,
                fontSize: font.id == 'script' || font.id == 'hand' || font.id == 'pacifico' || font.id == 'caveat' ? 18 : 14,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stylesBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        _letterPresets(),
        const SizedBox(height: 12),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SubTab(label: 'Texto', selected: _styleTab == _StyleSubTab.text, onTap: () => setState(() => _styleTab = _StyleSubTab.text)),
              _SubTab(label: 'Fondo', selected: _styleTab == _StyleSubTab.background, onTap: () => setState(() => _styleTab = _StyleSubTab.background)),
              _SubTab(label: 'Espaciado', selected: _styleTab == _StyleSubTab.spacing, onTap: () => setState(() => _styleTab = _StyleSubTab.spacing)),
              _SubTab(label: 'Negrita cursiva', selected: _styleTab == _StyleSubTab.format, onTap: () => setState(() => _styleTab = _StyleSubTab.format)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        switch (_styleTab) {
          _StyleSubTab.text => _textoControls(),
          _StyleSubTab.background => _fondoControls(),
          _StyleSubTab.spacing => _espaciadoControls(),
          _StyleSubTab.format => _formatoControls(),
        },
        ],
      ),
    );
  }

  void _applyLetterPreset(_LetterPreset preset) {
    setState(() {
      _textColor = preset.color;
      _strokeColor = preset.strokeColor;
      _strokeWidth = preset.strokeWidth;
      _shadow = preset.shadow;
    });
  }

  Widget _letterPresets() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _LetterPreset.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final preset = _LetterPreset.all[i];
          return GestureDetector(
            onTap: () => _applyLetterPreset(preset),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: preset.none
                  ? const Icon(Icons.block, color: Colors.white70, size: 22)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        if (preset.strokeWidth > 0)
                          Text(
                            'Aa',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 2.4
                                ..color = preset.strokeColor,
                            ),
                          ),
                        Text(
                          'Aa',
                          style: TextStyle(
                            color: preset.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            shadows: preset.shadow
                                ? [
                                    Shadow(
                                      blurRadius: 8,
                                      color: preset.strokeColor.withValues(alpha: 0.85),
                                      offset: Offset.zero,
                                    ),
                                  ]
                                : const [],
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

  Widget _sizeSlider() {
    final limit = _maxFontSize < _minFontSize ? _minFontSize : _maxFontSize;
    final max = limit <= _minFontSize ? _minFontSize + 0.01 : limit;
    return Column(
      children: [
        Row(
          children: [
            const Text('Aa', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: _fontSize.clamp(_minFontSize, limit),
                  min: _minFontSize,
                  max: max,
                  activeColor: KairoColors.primary400,
                  inactiveColor: const Color(0xFF3A3A3A),
                  onChanged: (v) {
                    setState(() => _fontSize = v.clamp(_minFontSize, limit));
                    if (v >= limit - 0.05) _notifyTextLimit();
                    WidgetsBinding.instance.addPostFrameCallback((_) => _limitFontToCanvas());
                  },
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${_fontSize.round()}',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (_atTextLimit)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              'Ya no cabe más en la imagen',
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  void _onScaleChanged(double value) {
    final limit = _maxSizeScale < _minScale ? _minScale : _maxSizeScale;
    setState(() => _sizeScale = value.clamp(_minScale, limit));
    if (value >= limit - 0.02) _notifyTextLimit();
    WidgetsBinding.instance.addPostFrameCallback((_) => _limitFontToCanvas());
  }

  Widget _textoControls() {
    return Column(
      children: [
        _LabeledSlider(
          label: 'Opacidad',
          value: _opacity,
          min: 0.2,
          max: 1,
          onChanged: (v) => setState(() => _opacity = v),
        ),
        const SizedBox(height: 6),
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
                    border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2.4 : 1),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _fondoControls() {
    return Row(
      children: [
        _BgStyleTile(
          selected: _bgStyle == VerseBgStyle.none,
          onTap: () => setState(() => _bgStyle = VerseBgStyle.none),
          child: const Icon(Icons.block, color: Colors.white70, size: 26),
        ),
        const SizedBox(width: 10),
        _BgStyleTile(
          selected: _bgStyle == VerseBgStyle.block,
          onTap: () => setState(() => _bgStyle = VerseBgStyle.block),
          child: Container(
            width: 54,
            height: 36,
            alignment: Alignment.center,
            color: const Color(0xFF6B6B6B),
            child: const Text('AB\nABC', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, height: 1.15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        _BgStyleTile(
          selected: _bgStyle == VerseBgStyle.tight,
          onTap: () => setState(() => _bgStyle = VerseBgStyle.tight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), color: const Color(0xFF6B6B6B), child: const Text('AB', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              const SizedBox(height: 3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: const Color(0xFF6B6B6B), child: const Text('ABC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _espaciadoControls() {
    return Column(
      children: [
        Row(
          children: [
            _AlignButton(icon: Icons.format_align_left, selected: _align == TextAlign.left, onTap: () => setState(() => _align = TextAlign.left)),
            const SizedBox(width: 8),
            _AlignButton(icon: Icons.format_align_center, selected: _align == TextAlign.center, onTap: () => setState(() => _align = TextAlign.center)),
            const SizedBox(width: 8),
            _AlignButton(icon: Icons.format_align_right, selected: _align == TextAlign.right, onTap: () => setState(() => _align = TextAlign.right)),
          ],
        ),
        const SizedBox(height: 8),
        _LabeledSlider(
          label: 'Escala',
          value: _sizeScale.clamp(_minScale, _maxSizeScale < _minScale ? _minScale : _maxSizeScale),
          min: _minScale,
          max: _maxSizeScale <= _minScale ? _minScale + 0.01 : _maxSizeScale,
          onChanged: _onScaleChanged,
        ),
        _LabeledSlider(label: 'Carácter', value: _letterSpacing, min: -2, max: 8, onChanged: (v) => setState(() => _letterSpacing = v)),
        _LabeledSlider(label: 'Línea', value: _lineHeight, min: 0.9, max: 2, onChanged: (v) => setState(() => _lineHeight = v)),
      ],
    );
  }

  Widget _formatoControls() {
    return Row(
      children: [
        _FormatTile(label: 'B', selected: _bold, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white), onTap: () => setState(() => _bold = !_bold)),
        const SizedBox(width: 10),
        _FormatTile(label: 'I', selected: _italic, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600), onTap: () => setState(() => _italic = !_italic)),
        const SizedBox(width: 10),
        _FormatTile(label: 'U', selected: _underline, style: const TextStyle(decoration: TextDecoration.underline, fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600), onTap: () => setState(() => _underline = !_underline)),
      ],
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
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => const SizedBox(
            width: 96,
            height: 64,
            child: BibleSkeletonBox(height: 64, borderRadius: 10),
          ),
        ),
      );
    }
    if (_photosError != null) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: KairoColors.darkCard, borderRadius: BorderRadius.circular(12)),
        child: TextButton(
          onPressed: () => _loadPhotos(force: true),
          child: Text(_photosError!, style: const TextStyle(color: KairoColors.darkTextSecondary)),
        ),
      );
    }
    return SizedBox(
      height: 64,
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
              width: 96,
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

class _LetterPreset {
  const _LetterPreset({
    required this.color,
    required this.strokeColor,
    required this.strokeWidth,
    required this.shadow,
    this.none = false,
  });

  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final bool shadow;
  final bool none;

  static const all = [
    _LetterPreset(color: Colors.white, strokeColor: Colors.black, strokeWidth: 0, shadow: false, none: true),
    _LetterPreset(color: Colors.white, strokeColor: Color(0xFF111111), strokeWidth: 2.4, shadow: false),
    _LetterPreset(color: Color(0xFF111111), strokeColor: Colors.white, strokeWidth: 2.4, shadow: false),
    _LetterPreset(color: Colors.white, strokeColor: Color(0xFF111111), strokeWidth: 0, shadow: true),
    _LetterPreset(color: Color(0xFF111111), strokeColor: Colors.white, strokeWidth: 0, shadow: true),
    _LetterPreset(color: Color(0xFFFBBF24), strokeColor: Color(0xFF111111), strokeWidth: 2.2, shadow: false),
    _LetterPreset(color: Color(0xFFEF4444), strokeColor: Colors.white, strokeWidth: 2.2, shadow: false),
    _LetterPreset(color: Color(0xFFF97316), strokeColor: Colors.white, strokeWidth: 2.2, shadow: false),
    _LetterPreset(color: Color(0xFF38BDF8), strokeColor: Colors.white, strokeWidth: 2.2, shadow: false),
  ];
}

enum _EditorMainTab { fonts, styles }

enum _StyleSubTab { text, background, spacing, format }

class _MainTab extends StatelessWidget {
  const _MainTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : KairoColors.darkTextSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 28,
            color: selected ? KairoColors.primary400 : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  const _SubTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : KairoColors.darkTextSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(label, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: KairoColors.primary400,
              inactiveColor: KairoColors.darkHover,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _BgStyleTile extends StatelessWidget {
  const _BgStyleTile({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: KairoColors.darkHover,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 1.6),
        ),
        child: child,
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.label, required this.selected, required this.style, required this.onTap});

  final String label;
  final bool selected;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KairoColors.darkHover,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 1.6),
          ),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

class _TightLineBackground extends StatelessWidget {
  const _TightLineBackground({
    required this.value,
    required this.style,
    required this.look,
    required this.child,
  });

  final String value;
  final TextStyle style;
  final VerseTextLook look;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textAlign: look.align,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final length = value.length;
        final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length));
        return CustomPaint(
          painter: _TightBgPainter(boxes: boxes, color: look.resolvedBg),
          child: child,
        );
      },
    );
  }
}

class _TightBgPainter extends CustomPainter {
  const _TightBgPainter({required this.boxes, required this.color});

  final List<TextBox> boxes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final box in boxes) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.toRect().inflate(4), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TightBgPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.boxes != boxes;
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
