import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bible_book.dart';

class BibleApi {
  BibleApi._();
  static final BibleApi instance = BibleApi._();

  static const translationId = 'spa_r09';
  static const translationLabel = 'RVR09';
  static const _base = 'https://bible.helloao.org';

  List<BibleBook>? _books;
  final Map<String, BibleChapter> _chapters = {};

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'KAIRO/1.0 (Flutter; Bible reader)',
  };

  Future<List<BibleBook>> fetchBooks() async {
    if (_books != null) return _books!;
    final res = await http
        .get(Uri.parse('$_base/api/$translationId/books.json'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar los libros (${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final raw = (data['books'] as List<dynamic>? ?? const []);
    final books = raw
        .map((e) => BibleBook.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    _books = books;
    return books;
  }

  Future<BibleBook> bookById(String id) async {
    final books = await fetchBooks();
    return books.firstWhere(
      (b) => b.id == id,
      orElse: () => throw Exception('Libro no encontrado'),
    );
  }

  Future<BibleChapter> fetchChapter(String bookId, int chapter) async {
    final key = '$bookId:$chapter';
    final cached = _chapters[key];
    if (cached != null) return cached;

    final res = await http
        .get(
          Uri.parse('$_base/api/$translationId/$bookId/$chapter.simple.json'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('No se pudo cargar el capítulo (${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final book = data['book'] as Map<String, dynamic>? ?? const {};
    final chapterJson = data['chapter'] as Map<String, dynamic>? ?? const {};
    final content = chapterJson['content'] as List<dynamic>? ?? const [];
    final verses = <BibleVerse>[];
    for (final item in content) {
      if (item is! Map<String, dynamic>) continue;
      if (item['type'] != 'verse') continue;
      final n = item['number'];
      final text = (item['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;
      verses.add(
        BibleVerse(
          number: n is int ? n : int.tryParse('$n') ?? verses.length + 1,
          text: text,
        ),
      );
    }
    final parsed = BibleChapter(
      bookId: bookId,
      bookName: (book['commonName'] as String?) ??
          (book['name'] as String?) ??
          bookId,
      number: (chapterJson['number'] as int?) ?? chapter,
      verses: verses,
    );
    _chapters[key] = parsed;
    return parsed;
  }

  Future<BibleCitation?> fetchVerse(String bookId, int chapter, int verse) async {
    final ch = await fetchChapter(bookId, chapter);
    for (final v in ch.verses) {
      if (v.number == verse) {
        return BibleCitation(
          bookId: bookId,
          bookName: _shortName(ch.bookName),
          chapter: chapter,
          verse: verse,
          text: v.text,
        );
      }
    }
    return null;
  }

  static String _shortName(String name) {
    if (name.startsWith('San ')) return name.substring(4);
    return name;
  }
}

String foldBibleQuery(String input) {
  const map = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ü': 'u', 'Ñ': 'n',
  };
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    buf.write(map[ch] ?? ch);
  }
  return buf.toString().toLowerCase().trim();
}

BibleCitation? parseBibleQuery(String query, List<BibleBook> books) {
  final raw = query.trim();
  if (raw.isEmpty) return null;
  final match = RegExp(r'^(.+?)\s+(\d+)(?::(\d+))?$').firstMatch(raw);
  if (match == null) return null;
  final nameQ = foldBibleQuery(match.group(1)!);
  final chapter = int.parse(match.group(2)!);
  final verse = int.tryParse(match.group(3) ?? '1') ?? 1;

  BibleBook? found;
  var bestLen = 0;
  for (final book in books) {
    for (final label in [book.displayName, book.commonName, book.name, book.id]) {
      final folded = foldBibleQuery(label);
      if (nameQ == folded || folded.startsWith(nameQ) || nameQ.startsWith(folded)) {
        if (folded.length > bestLen) {
          bestLen = folded.length;
          found = book;
        }
      }
    }
  }
  if (found == null) return null;
  if (chapter < 1 || chapter > found.numberOfChapters) return null;
  return BibleCitation(
    bookId: found.id,
    bookName: found.displayName,
    chapter: chapter,
    verse: verse < 1 ? 1 : verse,
    text: '',
  );
}
