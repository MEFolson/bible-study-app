class Book {
  final int id;
  final String code, name, testament;
  final int order;
  const Book(this.id, this.code, this.name, this.testament, this.order);
  bool get isOT => testament == 'OT';
  bool get isNT => testament == 'NT';
}

class Version {
  final int id;
  final String code, name, language, direction, scheme;
  final bool hasText, hasWords;
  const Version(
    this.id,
    this.code,
    this.name,
    this.language,
    this.direction,
    this.scheme,
    this.hasText,
    this.hasWords,
  );
  bool get rtl => direction == 'rtl';
}

class Word {
  final int id, chapter, verse, position;
  final String? type, translit, gloss, strongIds, lemma, morph, editions;

  /// Exactly as published by the source, byte for byte.
  final String textSrc;

  /// Display form from the pipeline: only the / and \ morpheme dividers removed.
  final String text;
  const Word(
    this.id,
    this.chapter,
    this.verse,
    this.position,
    this.type,
    this.textSrc,
    this.text,
    this.translit,
    this.gloss,
    this.strongIds,
    this.lemma,
    this.morph,
    this.editions,
  );
  List<String> get strongs => (strongIds ?? '')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
}

/// A reference in the KJV numbering used for navigation.
class Ref {
  final int book, chapter, verse;
  const Ref(this.book, this.chapter, this.verse);
  @override
  bool operator ==(Object other) =>
      other is Ref &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse;
  @override
  int get hashCode => Object.hash(book, chapter, verse);
}

/// One cell of the passage grid.
class Cell {
  final String? text;
  final List<Word>? words;

  /// Set when this column's own numbering differs from the navigation numbering, e.g. "Hebrew 32:1".
  final String? ownRef;
  const Cell({this.text, this.words, this.ownRef});
}

class PassageRow {
  final int verse; // 0 means a Psalm title
  Cell? original, septuagint, english;
  int xrefCount = 0;
  PassageRow(this.verse);
}

class LexEntry {
  final String source, strong, baseStrong;
  final String? lemma, translit, morph, gloss, definition;
  final bool baseOnly;
  const LexEntry(
    this.source,
    this.strong,
    this.baseStrong,
    this.lemma,
    this.translit,
    this.morph,
    this.gloss,
    this.definition,
    this.baseOnly,
  );
}

class CrossRef {
  final Ref to;
  final Ref? toEnd;
  final int votes;
  const CrossRef(this.to, this.toEnd, this.votes);
}
