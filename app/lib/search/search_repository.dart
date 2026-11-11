import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart' hide Version;

import '../data/bible_repository.dart';
import '../data/models.dart';
import 'search_text.dart';

/// One verse found by a search.
class SearchHit {
  final Version version;
  final Book book;
  final int chapter, verse;
  final String text;

  /// Where the reader should open it, in its KJV navigation numbering.
  final Ref ref;
  const SearchHit(
    this.version,
    this.book,
    this.chapter,
    this.verse,
    this.text,
    this.ref,
  );
}

class SearchPage {
  final int total;
  final List<SearchHit> hits;
  const SearchPage(this.total, this.hits);
}

typedef _Row = (int version, int book, int chapter, int verse, String text);

/// Full text search over verse_fts, the contentless FTS5 index pipeline/build.py builds from
/// fold(verse.text) with rowid = verse.id. The database is opened read only and never changed.
class SearchRepository {
  final BibleRepository bible;
  SearchRepository(this.bible);

  /// Versions that have verse text and so can be searched, English first, then Hebrew and Greek.
  List<Version> get searchable => [
    ...bible.versions.where((v) => v.hasText && v.language == 'eng'),
    ...bible.versions.where((v) => v.hasText && v.language != 'eng'),
  ];

  /// Searches [query] in [versions] (all versions when null). Runs on a background isolate with
  /// its own read only connection so typing stays smooth.
  Future<SearchPage> search(
    String query, {
    List<Version>? versions,
    int limit = 100,
    int offset = 0,
  }) async {
    final terms = parseQuery(query);
    if (terms.isEmpty) return const SearchPage(0, []);
    final expr = ftsExpression(terms);
    final path = bible.path;
    final ids = versions?.map((v) => v.id).toList();
    final (total, rows) = await Isolate.run(
      () => _runQuery(path, expr, ids, limit, offset),
    );
    return SearchPage(total, rows.map(_hit).toList());
  }

  /// Same as [search] but on the calling thread, for tests and small lookups.
  SearchPage searchSync(
    String query, {
    List<Version>? versions,
    int limit = 100,
    int offset = 0,
  }) {
    final terms = parseQuery(query);
    if (terms.isEmpty) return const SearchPage(0, []);
    final (total, rows) = _query(
      bible.db,
      ftsExpression(terms),
      versions?.map((v) => v.id).toList(),
      limit,
      offset,
    );
    return SearchPage(total, rows.map(_hit).toList());
  }

  SearchHit _hit(_Row r) {
    final v = bible.versions.firstWhere((x) => x.id == r.$1);
    final own = Ref(r.$2, r.$3, r.$4);
    final ref = bible.scheme(v) == 'Hebrew'
        ? (bible.hebToKjv[own] ?? own)
        : own;
    return SearchHit(v, bible.bookById[r.$2]!, r.$3, r.$4, r.$5, ref);
  }

  static (int, List<_Row>) _runQuery(
    String path,
    String expr,
    List<int>? versionIds,
    int limit,
    int offset,
  ) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return _query(db, expr, versionIds, limit, offset);
    } finally {
      db.close();
    }
  }

  static (int, List<_Row>) _query(
    Database db,
    String expr,
    List<int>? versionIds,
    int limit,
    int offset,
  ) {
    final filter = versionIds == null
        ? ''
        : ' AND v.version_id IN (${versionIds.map((_) => '?').join(',')})';
    final args = [expr, ...?versionIds];
    final total = versionIds == null
        ? db.select(
                'SELECT COUNT(*) AS n FROM verse_fts WHERE verse_fts MATCH ?',
                [expr],
              ).first['n']
              as int
        : db
                  .select(
                    'SELECT COUNT(*) AS n FROM verse_fts f JOIN verse v ON v.id = f.rowid '
                    'WHERE verse_fts MATCH ?$filter',
                    args,
                  )
                  .first['n']
              as int;
    final rows = [
      for (final r in db.select(
        'SELECT v.version_id, v.book_id, v.chapter, v.verse, v.text '
        'FROM verse_fts f JOIN verse v ON v.id = f.rowid JOIN book b ON b.id = v.book_id '
        'WHERE verse_fts MATCH ?$filter '
        'ORDER BY b.canon_order, v.chapter, v.verse, v.version_id LIMIT ? OFFSET ?',
        [...args, limit, offset],
      ))
        (
          r['version_id'] as int,
          r['book_id'] as int,
          r['chapter'] as int,
          r['verse'] as int,
          r['text'] as String,
        ),
    ];
    return (total, rows);
  }
}
