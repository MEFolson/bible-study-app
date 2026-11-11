import 'package:bible_study/data/bible_repository.dart';
import 'package:bible_study/data/db_locator.dart';
import 'package:bible_study/data/models.dart';
import 'package:bible_study/search/search_repository.dart';
import 'package:bible_study/search/search_screen.dart';
import 'package:bible_study/search/search_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fold', () {
    test('strips Hebrew points and cantillation, keeps the letters', () {
      // Genesis 1:1, first word, written as code points: bet dagesh sheva resh tsere alef shin
      // shin-dot hiriq tipeha yod tav.
      expect(
        fold(
          '\u05D1\u05BC\u05B0\u05E8\u05B5\u05D0\u05E9\u05C1\u05B4\u0596\u05D9\u05EA',
        ),
        '\u05D1\u05E8\u05D0\u05E9\u05D9\u05EA',
      );
    });
    test('strips Greek accents and breathings, lower case, final sigma', () {
      expect(fold('Ἐν ἀρχῇ ἦν ὁ λόγος'), 'εν αρχη ην ο λογοσ');
    });
    test('strips Latin accents and lower cases', () {
      expect(fold('Élie NAÏVE'), 'elie naive');
    });
  });

  group('parseQuery and ftsExpression', () {
    test('words, phrases and prefixes', () {
      final t = parseQuery('Love "in the  beginning" fait*');
      expect(t.length, 3);
      expect(t[0].words, ['love']);
      expect(t[1].words, ['in', 'the', 'beginning']);
      expect(t[2].prefix, isTrue);
      expect(ftsExpression(t), '"love" AND "in the beginning" AND "fait"*');
    });
    test('FTS5 syntax typed by the user is neutralised', () {
      final t = parseQuery('NEAR(a b) OR -c ^d');
      expect(
        ftsExpression(t),
        '"near" AND "a" AND "b" AND "or" AND "c" AND "d"',
      );
    });
    test('empty and punctuation only queries give no terms', () {
      expect(parseQuery(''), isEmpty);
      expect(parseQuery(' "" ,.; '), isEmpty);
    });
  });

  group('highlightRanges', () {
    test('whole words only, case and accents ignored', () {
      const s = 'Love is patient. Lovely love!';
      final r = highlightRanges(s, parseQuery('love'));
      expect(r.map((x) => s.substring(x.$1, x.$2)), ['Love', 'love']);
    });
    test('prefix and phrase', () {
      const s = 'In the beginning, God; and lovely loves.';
      expect(
        highlightRanges(
          s,
          parseQuery('"the beginning god" lov*'),
        ).map((x) => s.substring(x.$1, x.$2)),
        ['the beginning, God', 'lovely', 'loves'],
      );
    });
    test('Hebrew typed without points highlights the pointed word', () {
      const s =
          '\u05D1\u05BC\u05B0\u05E8\u05B5\u05D0\u05E9\u05C1\u05B4\u0596\u05D9\u05EA \u05D1\u05BC\u05B8\u05E8\u05B8\u05A3\u05D0';
      final r = highlightRanges(s, parseQuery('בראשית'));
      expect(r, [(0, 12)]);
    });
    test('Greek typed without accents', () {
      const s = 'Ἐν ἀρχῇ ἦν ὁ λόγος';
      final r = highlightRanges(s, parseQuery('λογος'));
      expect(r.map((x) => s.substring(x.$1, x.$2)), ['λόγος']);
    });
  });

  test('scriptOf', () {
    expect(scriptOf('love'), Script.latin);
    expect(scriptOf('אלהים'), Script.hebrew);
    expect(scriptOf('θεος'), Script.greek);
  });

  // Against the real bible.sqlite; skipped when it is not on this machine.
  final path = DbLocator.find(const []);
  final skip = path == null ? 'bible.sqlite not found' : null;
  group('search in bible.sqlite', () {
    late BibleRepository bible;
    late SearchRepository search;
    setUpAll(() {
      bible = BibleRepository.open(path!);
      search = SearchRepository(bible);
    });
    Version v(String code) => bible.versionByCode[code]!;

    test('English phrase in one translation, canonical order', () {
      final p = search.searchSync(
        '"in the beginning"',
        versions: [v('engbsb')],
      );
      expect(p.total, greaterThan(0));
      expect(p.hits.first.book.code, 'GEN');
      expect(p.hits.first.ref, Ref(1, 1, 1));
      expect(p.hits.every((h) => h.version.code == 'engbsb'), isTrue);
    });

    test('Hebrew with or without points finds Genesis 1:1', () {
      for (final q in ['בראשית', 'בְּרֵאשִׁית']) {
        final p = search.searchSync(q, versions: [v('tahot')]);
        expect(p.hits.first.ref, Ref(1, 1, 1), reason: q);
        // The displayed text keeps its vowel points.
        expect(RegExp('[\u05B0-\u05BC]').hasMatch(p.hits.first.text), isTrue);
      }
    });

    test('Greek with or without accents finds John 1:1', () {
      for (final q in ['λόγος', 'λογος']) {
        final p = search.searchSync(q, versions: [v('sblgnt')]);
        expect(p.total, 65, reason: q);
        expect(
          p.hits.any((h) => h.book.code == 'JHN' && h.ref == Ref(43, 1, 1)),
          isTrue,
        );
      }
    });

    test('Hebrew numbering is mapped to the reader numbering', () {
      final p = search.searchSync('כתנור', versions: [v('tahot')]);
      final mal = p.hits.firstWhere((h) => h.book.code == 'MAL');
      expect((mal.chapter, mal.verse), (3, 19));
      expect(mal.ref, Ref(39, 4, 1));
    });

    test('all texts and paging', () async {
      final first = await search.search('beginning', limit: 10);
      final second = await search.search('beginning', limit: 10, offset: 10);
      expect(first.total, 3373);
      expect(first.hits.length, 10);
      expect(second.hits.first.text, isNot(first.hits.first.text));
      expect(
        first.hits.map((h) => h.version.code).toSet().length,
        greaterThan(1),
      );
    });

    testWidgets('search screen finds, highlights and opens a verse', (
      tester,
    ) async {
      SearchHit? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  opened = await Navigator.of(context).push<SearchHit>(
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchScreen(search: search, initial: v('engbsb')),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('search.field')),
        '"in the beginning"',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      for (
        var i = 0;
        i < 50 && find.byKey(const Key('search.hit.0')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.textContaining('Genesis 1:1'), findsOneWidget);
      expect(
        find.textContaining('verses in Berean Standard Bible'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('search.hit.0')));
      await tester.pumpAndSettle();
      expect(opened?.ref, Ref(1, 1, 1));
      expect(opened?.version.code, 'engbsb');
    });

    testWidgets('Hebrew input is right to left and searches the Hebrew text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(search: search, initial: v('engbsb')),
        ),
      );
      await tester.enterText(find.byKey(const Key('search.field')), 'בראשית');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      for (
        var i = 0;
        i < 50 && find.byKey(const Key('search.hit.0')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      final field = tester.widget<TextField>(
        find.byKey(const Key('search.field')),
      );
      expect(field.textDirection, TextDirection.rtl);
      expect(find.textContaining('Hebrew letters typed'), findsOneWidget);
      expect(find.textContaining('Genesis 1:1'), findsOneWidget);
    });
  }, skip: skip);
}
