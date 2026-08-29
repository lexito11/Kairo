import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/bible_book.dart';
import '../services/bible_api.dart';
import '../widgets/bible_chrome.dart';

class BibleReaderView extends StatefulWidget {
  const BibleReaderView({
    super.key,
    required this.bookId,
    this.chapter = 1,
    this.initialVerse = 1,
  });

  final String bookId;
  final int chapter;
  final int initialVerse;

  @override
  State<BibleReaderView> createState() => _BibleReaderViewState();
}

class _BibleReaderViewState extends State<BibleReaderView> {
  BibleBook? _book;
  BibleChapter? _chapter;
  late int _chapterNumber;
  int? _highlightVerse;
  BibleVerse? _actionVerse;
  bool _loading = true;
  String? _error;
  final Map<int, GlobalKey> _verseKeys = {};

  @override
  void initState() {
    super.initState();
    _chapterNumber = widget.chapter < 1 ? 1 : widget.chapter;
    _highlightVerse = widget.initialVerse < 1 ? 1 : widget.initialVerse;
    _load(scrollTo: _highlightVerse);
  }

  Future<void> _load({int? scrollTo}) async {
    setState(() {
      _loading = true;
      _error = null;
      _actionVerse = null;
    });
    try {
      final book = await BibleApi.instance.bookById(widget.bookId);
      var chapterNum = _chapterNumber;
      if (chapterNum > book.numberOfChapters) chapterNum = 1;
      final chapter = await BibleApi.instance.fetchChapter(widget.bookId, chapterNum);
      _verseKeys
        ..clear()
        ..addEntries(chapter.verses.map((v) => MapEntry(v.number, GlobalKey())));
      if (!mounted) return;
      setState(() {
        _book = book;
        _chapter = chapter;
        _chapterNumber = chapterNum;
        _loading = false;
      });
      if (scrollTo != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToVerse(scrollTo));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el capítulo.';
        _loading = false;
      });
    }
  }

  BibleCitation _citationFor(BibleVerse verse) {
    final bookName = _book?.displayName ?? _chapter?.bookName ?? widget.bookId;
    return BibleCitation(
      bookId: widget.bookId,
      bookName: bookName,
      chapter: _chapterNumber,
      verse: verse.number,
      text: verse.text,
    );
  }

  void _scrollToVerse(int number) {
    final ctx = _verseKeys[number]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        alignment: 0.12,
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => _highlightVerse = number);
  }

  Future<void> _pickChapter() async {
    final book = _book;
    if (book == null) return;
    final selected = await _pickNumber(
      title: 'Buscar capítulo',
      count: book.numberOfChapters,
      current: _chapterNumber,
    );
    if (selected == null || selected == _chapterNumber) return;
    setState(() {
      _chapterNumber = selected;
      _highlightVerse = 1;
    });
    await _load(scrollTo: 1);
  }

  Future<void> _pickVerse() async {
    final chapter = _chapter;
    if (chapter == null || chapter.verses.isEmpty) return;
    final selected = await _pickNumber(
      title: 'Buscar versículo',
      count: chapter.verses.last.number,
      current: _highlightVerse ?? 1,
    );
    if (selected == null) return;
    setState(() => _actionVerse = null);
    _scrollToVerse(selected);
  }

  Future<int?> _pickNumber({
    required String title,
    required int count,
    required int current,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KairoColors.darkCard,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.58;
        return SizedBox(
          height: height,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      itemCount: count,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (context, i) {
                        final n = i + 1;
                        final active = n == current;
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, n),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? KairoColors.primary500 : KairoColors.darkHover,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$n',
                              style: TextStyle(
                                color: active ? Colors.white : KairoColors.darkTextSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onVerseTap(BibleVerse verse) {
    setState(() {
      if (_actionVerse?.number == verse.number) {
        _actionVerse = null;
      } else {
        _highlightVerse = verse.number;
        _actionVerse = verse;
      }
    });
  }

  Future<void> _copyVerse(BibleVerse verse) async {
    final citation = _citationFor(verse);
    await Clipboard.setData(ClipboardData(text: citation.clipboard));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Versículo copiado')),
    );
  }

  void _openImageCreator(BibleVerse verse) {
    final citation = _citationFor(verse);
    context.push(
      '/bible/image?text=${Uri.encodeComponent(citation.text)}&ref=${Uri.encodeComponent(citation.formatted)}',
    );
  }

  void _openImageEditor() {
    final verse = _actionVerse;
    if (verse != null) {
      _openImageCreator(verse);
      return;
    }
    context.push('/bible/image');
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      child: Column(
        children: [
          _header(),
          Expanded(
            child: Stack(
              children: [
                _body(),
                if (_actionVerse != null) _floatingActions(_actionVerse!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final top = MediaQuery.paddingOf(context).top;
    final bookName = _book?.displayName ?? '...';
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              const BibleBackButton(),
              const SizedBox(width: 8),
              const Icon(Icons.menu_book_rounded, color: KairoColors.primary400, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Capítulo $_chapterNumber · RVR09',
                      style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Creador de imagen',
                onPressed: _openImageEditor,
                style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                icon: const Icon(Icons.photo_outlined, color: KairoColors.primary400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _JumpChip(
                  icon: Icons.menu_book_outlined,
                  label: 'Buscar capítulo',
                  value: '$_chapterNumber',
                  onTap: _book == null ? null : _pickChapter,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _JumpChip(
                  icon: Icons.format_list_numbered,
                  label: 'Buscar versículo',
                  value: '${_highlightVerse ?? 1}',
                  onTap: _chapter == null ? null : _pickVerse,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const BibleVersesSkeleton();
    if (_error != null || _chapter == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Sin contenido', style: const TextStyle(color: KairoColors.darkTextSecondary)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _load(scrollTo: _highlightVerse),
              style: FilledButton.styleFrom(backgroundColor: KairoColors.primary500),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final verses = _chapter!.verses;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, _actionVerse == null ? 28 : 96),
      itemCount: verses.length,
      itemBuilder: (context, i) {
        final verse = verses[i];
        final selected = verse.number == (_actionVerse?.number ?? _highlightVerse);
        return KeyedSubtree(
          key: _verseKeys[verse.number],
          child: GestureDetector(
            onTap: () => _onVerseTap(verse),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? KairoColors.darkCard : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border.all(color: KairoColors.primary500.withValues(alpha: 0.45))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${verse.number}',
                      style: const TextStyle(
                        color: KairoColors.primary400,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      verse.text,
                      style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _floatingActions(BibleVerse verse) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: KairoColors.darkCard,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _FloatingAction(
                  icon: Icons.copy_rounded,
                  label: 'Copiar',
                  onTap: () => _copyVerse(verse),
                ),
              ),
              Container(width: 1, height: 36, color: KairoColors.darkHover),
              Expanded(
                child: _FloatingAction(
                  icon: Icons.photo_outlined,
                  label: 'Creador de imagen',
                  accent: true,
                  onTap: () => _openImageCreator(verse),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpChip extends StatelessWidget {
  const _JumpChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: KairoColors.darkCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: KairoColors.primary400, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: KairoColors.darkTextSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FloatingAction extends StatelessWidget {
  const _FloatingAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? KairoColors.primary400 : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
