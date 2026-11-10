import 'package:flutter/widgets.dart';

/// Wraps the whole app, dialogs included, for --screenshot.
final screenshotKey = GlobalKey();

/// Command line options. Used by the screenshot tests; all are optional.
///   --db=PATH            text database
///   --user-db=PATH       user database (notes, settings)
///   --goto=PSA.23.1      open at book code, chapter, verse
///   --english=engbsb     English version code
///   --original=tahot     original language column code
///   --lxx                show the Septuagint column (Old Testament)
///   --word=N             select the Nth word (from 1) of the goto verse in the original column
///   --panel=word|xref|notes
///   --screenshot=FILE    save a PNG of the window after loading, then quit
///   --pixel-ratio=2      scale for the screenshot
///   --dialog=books|credits  open a dialog first (for screenshots)
class LaunchOptions {
  String? db, userDb, gotoBook, english, original, panel, screenshot;
  int? gotoChapter, gotoVerse, word;
  double pixelRatio = 1;
  String? dialog;
  bool lxx = false;

  static LaunchOptions parse(List<String> args) {
    final o = LaunchOptions();
    for (final a in args) {
      final i = a.indexOf('=');
      final k = i < 0 ? a : a.substring(0, i);
      final v = i < 0 ? '' : a.substring(i + 1);
      switch (k) {
        case '--db':
          o.db = v;
        case '--user-db':
          o.userDb = v;
        case '--goto':
          final p = v.split('.');
          o.gotoBook = p[0].toUpperCase();
          if (p.length > 1) o.gotoChapter = int.tryParse(p[1]);
          if (p.length > 2) o.gotoVerse = int.tryParse(p[2]);
        case '--english':
          o.english = v;
        case '--original':
          o.original = v;
        case '--lxx':
          o.lxx = true;
        case '--word':
          o.word = int.tryParse(v);
        case '--panel':
          o.panel = v;
        case '--screenshot':
          o.screenshot = v;
        case '--pixel-ratio':
          o.pixelRatio = double.tryParse(v) ?? 1;
        case '--dialog':
          o.dialog = v;
      }
    }
    return o;
  }
}
