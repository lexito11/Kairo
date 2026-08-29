class BibleBook {
  const BibleBook({
    required this.id,
    required this.name,
    required this.commonName,
    required this.order,
    required this.numberOfChapters,
  });

  final String id;
  final String name;
  final String commonName;
  final int order;
  final int numberOfChapters;

  bool get isOldTestament => order >= 1 && order <= 39;
  bool get isNewTestament => order >= 40;

  /// Nombres más cortos para la grilla (p. ej. "Mateo" en vez de "San Mateo").
  String get displayName {
    if (commonName.startsWith('San ')) return commonName.substring(4);
    return commonName;
  }

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? json['commonName'] as String,
      commonName: (json['commonName'] as String?) ?? json['name'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
      numberOfChapters: (json['numberOfChapters'] as num?)?.toInt() ?? 0,
    );
  }
}

class BibleVerse {
  const BibleVerse({required this.number, required this.text});

  final int number;
  final String text;
}

class BibleChapter {
  const BibleChapter({
    required this.bookId,
    required this.bookName,
    required this.number,
    required this.verses,
  });

  final String bookId;
  final String bookName;
  final int number;
  final List<BibleVerse> verses;
}

class BibleCitation {
  const BibleCitation({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  final String bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;

  String get reference => '$bookName $chapter:$verse';
  String get formatted => '$reference - RVR09';
  String get clipboard => '$text\n$formatted';
}
