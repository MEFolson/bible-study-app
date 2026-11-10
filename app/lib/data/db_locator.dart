import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Finds the read only text database. Nothing is ever downloaded.
/// Search order:
///  1. --db=PATH on the command line
///  2. BIBLE_DB environment variable
///  3. data\bible.sqlite next to the app executable
///  4. bible.sqlite next to the app executable
///  5. BibleStudy\bible.sqlite in the user's application data folder
///  6. data/build/bible.sqlite in the working folder or any parent of it
///     (this is what makes `flutter run` work from the repository)
class DbLocator {
  static List<String> candidates(List<String> args) {
    final out = <String>[];
    for (final a in args) {
      if (a.startsWith('--db=')) out.add(a.substring(5));
    }
    final env = Platform.environment['BIBLE_DB'];
    if (env != null && env.isNotEmpty) out.add(env);
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    out.add('$exeDir${sep}data${sep}bible.sqlite');
    out.add('$exeDir${sep}bible.sqlite');
    final appData = Platform.isWindows
        ? Platform.environment['APPDATA']
        : '${Platform.environment['HOME']}/.local/share';
    if (appData != null) out.add('$appData${sep}BibleStudy${sep}bible.sqlite');
    for (final start in {Directory.current.absolute.path, exeDir}) {
      var d = Directory(start);
      for (var i = 0; i < 10; i++) {
        out.add('${d.path}${sep}data${sep}build${sep}bible.sqlite');
        if (d.parent.path == d.path) break;
        d = d.parent;
      }
    }
    return out;
  }

  static String? find(List<String> args) {
    for (final c in candidates(args)) {
      if (File(c).existsSync()) return File(c).absolute.path;
    }
    return null;
  }

  /// Where the separate user database (notes, settings) lives. Never the text database.
  static Future<String> userDbPath() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return '${dir.path}${Platform.pathSeparator}user.sqlite';
  }
}
