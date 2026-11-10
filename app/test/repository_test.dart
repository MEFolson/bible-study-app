import 'package:bible_study/data/models.dart';
import 'package:bible_study/data/bible_repository.dart';
import 'package:bible_study/data/db_locator.dart';
import 'package:bible_study/data/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

/// Runs against the real bible.sqlite built by pipeline/build.py. Skipped if it cannot be found.
void main() {
  final path = DbLocator.find(const []);
  final skip = path == null ? 'bible.sqlite not found' : null;

  group('bible.sqlite', () {
    late BibleRepository bible;
    setUpAll(() => bible = BibleRepository.open(path!));

    test('Genesis 1:1 Hebrew words keep vowel points and differ from the source only by / and \\', () {
      final gen = bible.bookByCode['GEN']!;
      final cells = bible.wordCells(bible.versionByCode['tahot']!, gen.id, 1);
      final words = cells[1]!.words!;
      // Source order: bet, dagesh, sheva (not the NFC order sheva, dagesh). Written as code points so no editor can normalise it.
      expect(
        words.first.textSrc,
        '\u05D1\u05BC\u05B0/\u05E8\u05B5\u05D0\u05E9\u05C1\u05B4\u0596\u05D9\u05EA',
      );
      final points = RegExp('[\u05B0-\u05BC\u05C1\u05C2\u05C7]');
      for (final w in words) {
        expect(w.text, w.textSrc.replaceAll('/', '').replaceAll('\\', ''));
        expect(points.hasMatch(w.text), isTrue, reason: w.text);
      }
    });

    test('Hebrew Malachi 3:19 sits in the KJV row Malachi 4:1', () {
      final mal = bible.bookByCode['MAL']!;
      final cells = bible.wordCells(bible.versionByCode['tahot']!, mal.id, 4);
      expect(cells[1]!.ownRef, '3:19');
    });

    test(
      'engjps and englee use English numbering despite the Hebrew label',
      () {
        expect(bible.scheme(bible.versionByCode['engjps']!), 'KJV');
        expect(bible.scheme(bible.versionByCode['englee']!), 'KJV');
      },
    );

    test('Strong ids resolve to STEP lexicons', () {
      expect(bible.lookup('H7225G').first.source, 'step-tbesh');
      expect(bible.lookup('G3056').first.source, 'step-tbesg');
      expect(bible.lookup('H3243J').first.baseOnly, isTrue);
    });

    test('cross references resolve to verses with text', () {
      final gen = bible.bookByCode['GEN']!;
      final x = bible.crossRefs(Ref(gen.id, 1, 1));
      expect(x, isNotEmpty);
      for (final r in x) {
        expect(
          bible.verseText(bible.versionByCode['eng-kjv2006']!, r.to),
          isNotNull,
        );
      }
    });

    test('the text database is opened read only', () {
      expect(
        () => bible.db.execute("INSERT INTO meta(key, value) VALUES('x', 'y')"),
        throwsA(anything),
      );
    });
  }, skip: skip);

  test('notes go to a separate user database and keep the two kinds apart', () {
    final dir = Directory.systemTemp.createTempSync();
    final u = UserRepository.open('${dir.path}/user.sqlite');
    u.saveNote('GEN', 1, 1, 'observation', 'seen');
    u.saveNote('GEN', 1, 1, 'interpretation', 'meant');
    expect(u.note('GEN', 1, 1, 'observation'), 'seen');
    expect(u.note('GEN', 1, 1, 'interpretation'), 'meant');
    expect(() => u.saveNote('GEN', 1, 1, 'mixed', 'x'), throwsA(anything));
    u.close();
  });
}
