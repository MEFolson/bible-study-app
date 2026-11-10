import 'package:sqlite3/sqlite3.dart' hide Version;

import 'models.dart';

/// Read only access to bible.sqlite as built by pipeline/build.py.
/// Every query here uses only tables and columns that exist in pipeline/schema.sql.
class BibleRepository {
  final Database db;
  final String path;
  late final List<Book> books;
  late final Map<int, Book> bookById;
  late final Map<String, Book> bookByCode;
  late final List<Version> versions;
  late final Map<String, Version> versionByCode;
  late final Map<String, String> sourceNames;
  final Map<int, Set<int>> _booksOfVersion = {};
  final Map<int, int> _chapterCount = {};

  /// Hebrew (book, chapter, verse) to KJV (chapter, verse), from TAHOT verse.alt_ref. Only rows that differ.
  final Map<Ref, Ref> hebToKjv = {};
  final Map<Ref, Ref> kjvToHeb = {};

  BibleRepository._(this.db, this.path);

  static BibleRepository open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    final r = BibleRepository._(db, path);
    r._load();
    return r;
  }

  void _load() {
    books = [
      for (final r in db.select(
        'SELECT id, code, name, testament, canon_order FROM book ORDER BY canon_order',
      ))
        Book(
          r['id'] as int,
          r['code'] as String,
          r['name'] as String,
          r['testament'] as String,
          r['canon_order'] as int,
        ),
    ];
    bookById = {for (final b in books) b.id: b};
    bookByCode = {for (final b in books) b.code: b};
    versions = [
      for (final r in db.select(
        'SELECT id, code, name, language, direction, scheme, has_text, has_words FROM version ORDER BY id',
      ))
        Version(
          r['id'] as int,
          r['code'] as String,
          r['name'] as String,
          r['language'] as String,
          r['direction'] as String,
          r['scheme'] as String,
          r['has_text'] == 1,
          r['has_words'] == 1,
        ),
    ];
    versionByCode = {for (final v in versions) v.code: v};
    sourceNames = {
      for (final r in db.select('SELECT id, name FROM source'))
        r['id'] as String: r['name'] as String,
    };
    final tahot = versionByCode['tahot'];
    if (tahot != null) {
      for (final r in db.select(
        'SELECT book_id, chapter, verse, alt_ref FROM verse WHERE version_id = ? AND alt_ref IS NOT NULL',
        [tahot.id],
      )) {
        final k = parseRef(r['alt_ref'] as String);
        if (k == null) continue;
        final h = Ref(
          r['book_id'] as int,
          r['chapter'] as int,
          r['verse'] as int,
        );
        hebToKjv[h] = k;
        kjvToHeb[k] = h;
      }
    }
  }

  /// Parses the pipeline's "GEN 31:55" form.
  Ref? parseRef(String s) {
    final m = RegExp(r'^(\w+) (\d+):(\d+)$').firstMatch(s.trim());
    if (m == null) return null;
    final b = bookByCode[m.group(1)];
    if (b == null) return null;
    return Ref(b.id, int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  String meta(String key) =>
      (db.select('SELECT value FROM meta WHERE key = ?', [
            key,
          ]).firstOrNull?['value']
          as String?) ??
      '';

  List<Version> get englishVersions =>
      versions.where((v) => v.language == 'eng' && v.hasText).toList();

  Set<int> booksOf(Version v) => _booksOfVersion.putIfAbsent(v.id, () {
    final table = v.hasText ? 'verse' : 'word';
    return {
      for (final r in db.select(
        'SELECT DISTINCT book_id FROM $table WHERE version_id = ?',
        [v.id],
      ))
        r['book_id'] as int,
    };
  });

  int _maxChapter(String code, int book) {
    final v = versionByCode[code];
    if (v == null) return 0;
    return (db.select(
              'SELECT MAX(chapter) AS m FROM verse WHERE version_id = ? AND book_id = ?',
              [v.id, book],
            ).first['m']
            as int?) ??
        0;
  }

  /// Chapters offered for navigation, in KJV numbering where the KJV has the book.
  int chapterCount(Book b, Version english) =>
      _chapterCount.putIfAbsent(b.id * 1000 + english.id, () {
        for (final code in [
          'eng-kjv2006',
          if (scheme(english) != 'Hebrew') english.code,
          'eng-kjv',
          'eng-Brenton',
          'grcbrent',
        ]) {
          final m = _maxChapter(code, b.id);
          if (m > 0) return m;
        }
        return 0;
      });

  // ---------- passage loading, keyed by KJV chapter and verse ----------

  final Map<int, String> _scheme = {};

  /// The numbering a version really uses. The pipeline labels engjps and englee as Hebrew, but their
  /// eBible files use English numbering (Genesis 31 has 55 verses, Malachi has 4 chapters), so the
  /// label is checked against the data: Hebrew numbering ends Genesis 31 at verse 54 and Malachi 3 at 24.
  String scheme(Version v) => _scheme.putIfAbsent(v.id, () {
    if (v.scheme != 'Hebrew') return v.scheme;
    int maxVerse(String code, int ch) {
      final b = bookByCode[code];
      if (b == null) return 0;
      return (db.select(
                'SELECT MAX(verse) AS m FROM verse WHERE version_id = ? AND book_id = ? AND chapter = ?',
                [v.id, b.id, ch],
              ).first['m']
              as int?) ??
          0;
    }

    final g = maxVerse('GEN', 31), m = maxVerse('MAL', 3);
    if (g == 55 || m == 18) return 'KJV';
    return 'Hebrew';
  });

  /// Text cells of a version for one navigation chapter. Hebrew scheme texts are mapped to KJV numbering
  /// through TAHOT's own alt_ref data; other schemes are shown with their own numbers.
  Map<int, Cell> textCells(Version v, int book, int chapter) {
    final out = <int, Cell>{};
    if (scheme(v) == 'Hebrew') {
      final refs = _hebrewRefs(book, chapter);
      if (refs.isEmpty) return out;
      final chapters = refs.keys.map((r) => r.chapter).toSet().join(',');
      for (final r in db.select(
        'SELECT chapter, verse, text FROM verse WHERE version_id = ? AND book_id = ? AND chapter IN ($chapters)',
        [v.id, book],
      )) {
        final own = Ref(book, r['chapter'] as int, r['verse'] as int);
        final k = refs[own];
        if (k == null) continue;
        out[k] = Cell(
          text: r['text'] as String,
          ownRef: own.chapter != chapter || own.verse != k
              ? '${own.chapter}:${own.verse}'
              : null,
        );
      }
      return out;
    }
    for (final r in db.select(
      'SELECT verse, text FROM verse WHERE version_id = ? AND book_id = ? AND chapter = ?',
      [v.id, book, chapter],
    )) {
      out[r['verse'] as int] = Cell(text: r['text'] as String);
    }
    return out;
  }

  /// Hebrew refs whose KJV equivalent lies in [chapter], mapped to the KJV verse number.
  Map<Ref, int> _hebrewRefs(int book, int chapter) {
    final tahot = versionByCode['tahot']!;
    final code = bookById[book]!.code;
    final out = <Ref, int>{};
    for (final r in db.select(
      'SELECT chapter, verse, alt_ref FROM verse WHERE version_id = ? AND book_id = ? AND ((chapter = ? AND alt_ref IS NULL) OR alt_ref LIKE ?)',
      [tahot.id, book, chapter, '$code $chapter:%'],
    )) {
      final own = Ref(book, r['chapter'] as int, r['verse'] as int);
      final alt = r['alt_ref'] as String?;
      out[own] = alt == null ? own.verse : parseRef(alt)!.verse;
    }
    return out;
  }

  /// Tagged word cells. TAHOT is mapped to KJV numbering; rows of type X (words supplied from the
  /// Septuagint, not in the Hebrew text) are left out, exactly as the pipeline does for verse text.
  /// For TAGNT only words present in NA28 are shown, so variant readings are not mixed into one line.
  Map<int, Cell> wordCells(Version v, int book, int chapter) {
    final out = <int, Cell>{};
    Map<Ref, int>? heb;
    String chapters = '$chapter';
    if (v.code == 'tahot') {
      heb = _hebrewRefs(book, chapter);
      if (heb.isEmpty) return out;
      chapters = heb.keys.map((r) => r.chapter).toSet().join(',');
    }
    final grouped = <Ref, List<Word>>{};
    for (final r in db.select(
      'SELECT id, chapter, verse, position, word_type, text_src, text, translit, gloss, strong_ids, lemma, morph, editions '
      'FROM word WHERE version_id = ? AND book_id = ? AND chapter IN ($chapters) ORDER BY chapter, verse, position',
      [v.id, book],
    )) {
      final w = Word(
        r['id'] as int,
        r['chapter'] as int,
        r['verse'] as int,
        r['position'] as int,
        r['word_type'] as String?,
        r['text_src'] as String,
        r['text'] as String,
        r['translit'] as String?,
        r['gloss'] as String?,
        r['strong_ids'] as String?,
        r['lemma'] as String?,
        r['morph'] as String?,
        r['editions'] as String?,
      );
      if (v.code == 'tahot' && w.type == 'X') continue;
      if (v.code == 'tagnt' && !(w.editions ?? '').contains('NA28')) continue;
      grouped.putIfAbsent(Ref(book, w.chapter, w.verse), () => []).add(w);
    }
    grouped.forEach((own, ws) {
      if (heb != null) {
        final k = heb[own];
        if (k == null) return;
        out[k] = Cell(
          words: ws,
          ownRef: own.chapter != chapter || own.verse != k
              ? '${own.chapter}:${own.verse}'
              : null,
        );
      } else {
        out[own.verse] = Cell(words: ws);
      }
    });
    return out;
  }

  Map<int, Cell> cells(Version v, int book, int chapter) =>
      v.hasWords &&
          (v.code == 'tahot' ||
              v.code == 'tagnt' ||
              v.code == 'byz-rp2018' ||
              v.code == 'nestle1904')
      ? wordCells(v, book, chapter)
      : textCells(v, book, chapter);

  List<PassageRow> passage({
    required int book,
    required int chapter,
    required Version english,
    Version? original,
    Version? septuagint,
  }) {
    final rows = <int, PassageRow>{};
    PassageRow row(int v) => rows.putIfAbsent(v, () => PassageRow(v));
    textCells(english, book, chapter).forEach((v, c) => row(v).english = c);
    if (original != null)
      cells(original, book, chapter).forEach((v, c) => row(v).original = c);
    if (septuagint != null)
      textCells(
        septuagint,
        book,
        chapter,
      ).forEach((v, c) => row(v).septuagint = c);
    for (final r in db.select(
      'SELECT from_verse, COUNT(*) AS n FROM crossref WHERE from_book = ? AND from_chapter = ? GROUP BY from_verse',
      [book, chapter],
    )) {
      rows[r['from_verse'] as int]?.xrefCount = r['n'] as int;
    }
    final list = rows.values.toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    return list;
  }

  // ---------- lexicon ----------

  static final _strongRe = RegExp(r'^([HG])(\d+)([A-Za-z]?)$');

  String? baseOf(String id) {
    final m = _strongRe.firstMatch(id);
    if (m == null) return null;
    return '${m.group(1)}${int.parse(m.group(2)!).toString().padLeft(4, '0')}';
  }

  /// STEP lexicon entry for the exact id (falling back to the base number, flagged), plus Open Scriptures Strong's.
  List<LexEntry> lookup(String id) {
    final base = baseOf(id);
    if (base == null) return [];
    final heb = id.startsWith('H');
    final step = heb ? 'step-tbesh' : 'step-tbesg';
    final os = heb ? 'os-strongs-heb' : 'os-strongs-grk';
    LexEntry mk(Row r, bool baseOnly) => LexEntry(
      r['source_id'] as String,
      r['strong'] as String,
      r['base_strong'] as String,
      r['lemma'] as String?,
      r['translit'] as String?,
      r['morph'] as String?,
      r['gloss'] as String?,
      r['definition'] as String?,
      baseOnly,
    );
    const cols =
        'source_id, strong, base_strong, lemma, translit, morph, gloss, definition';
    final out = <LexEntry>[];
    final exact = db.select(
      'SELECT $cols FROM lexicon WHERE source_id = ? AND strong = ?',
      [step, id],
    );
    if (exact.isNotEmpty) {
      out.add(mk(exact.first, false));
    } else {
      for (final r in db.select(
        'SELECT $cols FROM lexicon WHERE source_id = ? AND base_strong = ? ORDER BY strong LIMIT 3',
        [step, base],
      )) {
        out.add(mk(r, true));
      }
    }
    for (final r in db.select(
      'SELECT $cols FROM lexicon WHERE source_id = ? AND strong = ?',
      [os, base],
    )) {
      out.add(mk(r, false));
    }
    return out;
  }

  // ---------- cross references ----------

  List<CrossRef> crossRefs(Ref from) => [
    for (final r in db.select(
      'SELECT to_book, to_chapter, to_verse, to_end_book, to_end_chapter, to_end_verse, votes FROM crossref '
      'WHERE from_book = ? AND from_chapter = ? AND from_verse = ? ORDER BY votes DESC, id',
      [from.book, from.chapter, from.verse],
    ))
      CrossRef(
        Ref(r['to_book'] as int, r['to_chapter'] as int, r['to_verse'] as int),
        r['to_end_book'] == null
            ? null
            : Ref(
                r['to_end_book'] as int,
                r['to_end_chapter'] as int,
                r['to_end_verse'] as int,
              ),
        r['votes'] as int,
      ),
  ];

  /// Text of one KJV numbered verse in a version, for previews.
  String? verseText(Version v, Ref ref) {
    var own = ref;
    if (scheme(v) == 'Hebrew') own = kjvToHeb[ref] ?? ref;
    return db.select(
          'SELECT text FROM verse WHERE version_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
          [v.id, own.book, own.chapter, own.verse],
        ).firstOrNull?['text']
        as String?;
  }

  String label(Ref r, {Ref? end}) {
    final b = bookById[r.book]?.name ?? '?';
    var s = '$b ${r.chapter}:${r.verse}';
    if (end != null) {
      if (end.book != r.book) {
        s += ' to ${bookById[end.book]?.name} ${end.chapter}:${end.verse}';
      } else if (end.chapter != r.chapter) {
        s += ' to ${end.chapter}:${end.verse}';
      } else if (end.verse != r.verse) {
        s += ' to ${end.verse}';
      }
    }
    return s;
  }

  List<Map<String, String>> credits() => [
    for (final r in db.select(
      'SELECT id, name, licence_class, licence_url, credit FROM source ORDER BY name',
    ))
      {
        for (final k in [
          'id',
          'name',
          'licence_class',
          'licence_url',
          'credit',
        ])
          k: (r[k] ?? '').toString(),
      },
  ];

  void close() => db.close();
}
