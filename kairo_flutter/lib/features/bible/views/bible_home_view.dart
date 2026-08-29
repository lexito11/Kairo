import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/bible_book.dart';
import '../services/bible_api.dart';
import '../widgets/bible_chrome.dart';

class BibleHomeView extends StatefulWidget {
  const BibleHomeView({super.key});

  @override
  State<BibleHomeView> createState() => _BibleHomeViewState();
}

class _BibleHomeViewState extends State<BibleHomeView> {
  final _search = TextEditingController();
  List<BibleBook> _books = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final books = await BibleApi.instance.fetchBooks();
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con la Biblia. Revisa tu conexión.';
        _loading = false;
      });
    }
  }

  void _openBook(BibleBook book) {
    context.push('/bible/read/${book.id}?chapter=1&verse=1');
  }

  void _onSearchSubmitted(String value) {
    final hit = parseBibleQuery(value, _books);
    if (hit == null) return;
    context.push('/bible/read/${hit.bookId}?chapter=${hit.chapter}&verse=${hit.verse}');
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      child: Column(
        children: [
          _header(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              const BibleBackButton(),
              const SizedBox(width: 8),
              const Icon(Icons.menu_book_rounded, color: KairoColors.primary400, size: 26),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biblia',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Selecciona un libro',
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Versículos guardados',
                onPressed: () => context.push('/bible/saved'),
                style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
                icon: const Icon(Icons.bookmark_rounded, color: KairoColors.primary400),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BibleSearchField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            onSubmitted: _onSearchSubmitted,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push('/bible/saved'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bookmark_outline, color: KairoColors.primary400, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Versículos guardados',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: KairoColors.darkTextSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: const [
          Row(
            children: [
              Expanded(child: _SectionTitle(icon: Icons.history_edu_outlined, title: 'Antiguo Testamento')),
              SizedBox(width: 8),
              Expanded(child: _SectionTitle(icon: Icons.auto_stories_outlined, title: 'Nuevo Testamento')),
            ],
          ),
          SizedBox(height: 8),
          BibleBooksSkeleton(),
        ],
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: KairoColors.darkTextSecondary)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(
                  backgroundColor: KairoColors.primary500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final q = foldBibleQuery(_search.text);
    final parsed = parseBibleQuery(_search.text, _books);
    final ot = _books.where((b) => b.isOldTestament).where((b) => q.isEmpty || _matches(b, q)).toList();
    final nt = _books.where((b) => b.isNewTestament).where((b) => q.isEmpty || _matches(b, q)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        if (parsed != null) ...[
          GestureDetector(
            onTap: () => context.push(
              '/bible/read/${parsed.bookId}?chapter=${parsed.chapter}&verse=${parsed.verse}',
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward, color: KairoColors.primary400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ir a ${parsed.bookName} ${parsed.chapter}:${parsed.verse} - RVR09',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (q.isNotEmpty && ot.isEmpty && nt.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text('No se encontraron libros', style: TextStyle(color: KairoColors.darkTextSecondary)),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TestamentColumn(
                  title: 'Antiguo Testamento',
                  icon: Icons.history_edu_outlined,
                  books: ot,
                  onOpen: _openBook,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TestamentColumn(
                  title: 'Nuevo Testamento',
                  icon: Icons.auto_stories_outlined,
                  books: nt,
                  onOpen: _openBook,
                ),
              ),
            ],
          ),
      ],
    );
  }

  bool _matches(BibleBook book, String q) {
    return foldBibleQuery(book.displayName).contains(q) ||
        foldBibleQuery(book.commonName).contains(q) ||
        foldBibleQuery(book.name).contains(q);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: KairoColors.primary400, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TestamentColumn extends StatelessWidget {
  const _TestamentColumn({
    required this.title,
    required this.icon,
    required this.books,
    required this.onOpen,
  });

  final String title;
  final IconData icon;
  final List<BibleBook> books;
  final void Function(BibleBook book) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: icon, title: title),
        const SizedBox(height: 8),
        for (final book in books)
          GestureDetector(
            onTap: () => onOpen(book),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '${book.numberOfChapters} ${book.numberOfChapters == 1 ? 'capítulo' : 'capítulos'}',
                    style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
