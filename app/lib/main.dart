import 'dart:io';

import 'package:flutter/material.dart';

import 'data/bible_repository.dart';
import 'data/bundled_db.dart';
import 'data/db_locator.dart';
import 'data/user_repository.dart';
import 'reader/reader_screen.dart';
import 'settings/launch_options.dart';
import 'settings/text_styles.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final opts = LaunchOptions.parse(args);
  String? dbPath;
  if (Platform.isAndroid || Platform.isIOS) {
    // Mobile: unpack the bundled copy once, then open it read only.
    final status = ValueNotifier<(double, String)>((
      0,
      'Opening the Bible texts',
    ));
    runApp(PreparingApp(status: status));
    try {
      dbPath = await BundledDb.ensure(
        progress: (d, m) => status.value = (d, m),
      );
    } catch (e) {
      status.value = (
        -1,
        'Could not prepare the Bible texts: $e. Check that the device has about 500 MB free, then reopen the app.',
      );
      return;
    }
  } else {
    dbPath = DbLocator.find(args);
  }
  if (dbPath == null) {
    runApp(MissingDbApp(searched: DbLocator.candidates(args)));
    return;
  }
  final bible = BibleRepository.open(dbPath);
  final userPath = opts.userDb ?? await DbLocator.userDbPath();
  final user = UserRepository.open(userPath);
  runApp(BibleStudyApp(bible: bible, user: user, options: opts));
}

/// First launch screen on Android and iOS while the database is unpacked.
class PreparingApp extends StatelessWidget {
  final ValueNotifier<(double, String)> status;
  const PreparingApp({super.key, required this.status});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ValueListenableBuilder<(double, String)>(
            valueListenable: status,
            builder: (_, s, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Zagros Bible Study', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 24),
                if (s.$1 >= 0)
                  LinearProgressIndicator(value: s.$1 == 0 ? null : s.$1),
                const SizedBox(height: 16),
                Text(s.$2, textAlign: TextAlign.center),
                if (s.$1 >= 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'The first launch can take a minute. Nothing is downloaded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class BibleStudyApp extends StatelessWidget {
  final BibleRepository bible;
  final UserRepository user;
  final LaunchOptions options;
  const BibleStudyApp({
    super.key,
    required this.bible,
    required this.user,
    required this.options,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Zagros Bible Study',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF6B4E2E),
      useMaterial3: true,
      fontFamily: Fonts.latin,
    ),
    builder: (context, child) =>
        RepaintBoundary(key: screenshotKey, child: child),
    home: ReaderScreen(bible: bible, user: user, options: options),
  );
}

class MissingDbApp extends StatelessWidget {
  final List<String> searched;
  const MissingDbApp({super.key, required this.searched});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: ListView(
          children: [
            const Text(
              'bible.sqlite was not found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This app never downloads texts. Put bible.sqlite in one of these places, or start the app with --db=PATH:',
            ),
            const SizedBox(height: 12),
            for (final s in searched)
              SelectableText(
                s,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => exit(1),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}
