import 'package:sqlite3/sqlite3.dart';

/// The user's own database (notes and settings). It is a separate file from bible.sqlite,
/// which is opened read only and never written.
class UserRepository {
  final Database db;
  final String path;
  UserRepository._(this.db, this.path);

  static const kinds = ['observation', 'interpretation'];

  static UserRepository open(String path) {
    final db = sqlite3.open(path);
    db.execute('''
      CREATE TABLE IF NOT EXISTS setting (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS note (
        id INTEGER PRIMARY KEY,
        book_code TEXT NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL,
        kind TEXT NOT NULL CHECK (kind IN ('observation', 'interpretation')),
        body TEXT NOT NULL,
        created TEXT NOT NULL, updated TEXT NOT NULL,
        UNIQUE (book_code, chapter, verse, kind));
    ''');
    return UserRepository._(db, path);
  }

  String? get(String key) =>
      db.select('SELECT value FROM setting WHERE key = ?', [
            key,
          ]).firstOrNull?['value']
          as String?;
  void set(String key, String value) => db.execute(
    'INSERT INTO setting(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    [key, value],
  );

  String note(String book, int chapter, int verse, String kind) =>
      (db.select(
            'SELECT body FROM note WHERE book_code = ? AND chapter = ? AND verse = ? AND kind = ?',
            [book, chapter, verse, kind],
          ).firstOrNull?['body']
          as String?) ??
      '';

  void saveNote(String book, int chapter, int verse, String kind, String body) {
    assert(kinds.contains(kind));
    final now = DateTime.now().toIso8601String();
    if (body.trim().isEmpty) {
      db.execute(
        'DELETE FROM note WHERE book_code = ? AND chapter = ? AND verse = ? AND kind = ?',
        [book, chapter, verse, kind],
      );
      return;
    }
    db.execute(
      '''INSERT INTO note(book_code, chapter, verse, kind, body, created, updated) VALUES(?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(book_code, chapter, verse, kind) DO UPDATE SET body = excluded.body, updated = excluded.updated''',
      [book, chapter, verse, kind, body, now, now],
    );
  }

  Set<int> versesWithNotes(String book, int chapter) => {
    for (final r in db.select(
      'SELECT DISTINCT verse FROM note WHERE book_code = ? AND chapter = ?',
      [book, chapter],
    ))
      r['verse'] as int,
  };

  void close() => db.close();
}
