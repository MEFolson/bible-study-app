import 'dart:io';

import 'package:bible_study/data/bible_repository.dart';
import 'package:bible_study/data/bundled_db.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unpacks the real assets/db parts exactly as the phone does on first launch, then checks the copy is
/// byte identical to ../data/build/bible.sqlite and opens read only.
void main() {
  final manifest = File('assets/db/manifest.json');
  final source = File('../data/build/bible.sqlite');
  test(
    'first launch copy matches bible.sqlite and is reused on the next launch',
    () async {
      final dir = Directory.systemTemp.createTempSync('bundled');
      final calls = <String>[];
      Future<String> run() => BundledDb.unpack(
        manifestJson: manifest.readAsStringSync(),
        loadPart: (n) async {
          calls.add(n);
          return File('assets/db/$n').readAsBytes();
        },
        targetDir: dir,
      );
      final sw = Stopwatch()..start();
      final path = await run();
      final firstMs = sw.elapsedMilliseconds;
      expect(File(path).lengthSync(), source.lengthSync());
      expect(
        sha256.convert(File(path).readAsBytesSync()),
        sha256.convert(source.readAsBytesSync()),
      );
      final n = calls.length;
      await run();
      expect(calls.length, n, reason: 'second launch must not copy again');
      final bible = BibleRepository.open(path);
      expect(bible.englishVersions.length, 34);
      bible.close();
      // ignore: avoid_print
      print('unpacked $n parts in $firstMs ms on the build box');
      dir.deleteSync(recursive: true);
    },
    skip: manifest.existsSync() && source.existsSync()
        ? null
        : 'run tool/pack_db.py first',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
