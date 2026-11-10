# Bible Study reader (Windows, Android, iPhone)

A fully offline Flutter reader for `bible.sqlite`, the database built by `../pipeline`. It reads only that local file and never downloads texts. Windows, Android and iPhone are the targets; the Linux build exists only so Hebrew and Greek rendering can be checked on the build box.

**Android and iPhone:** see `../MOBILE.md`. In short: install `../dist/bible_study_android.apk` by opening it on the phone and allowing installs from that source; the first launch takes about a minute while the database is unpacked; an iPhone build needs a Mac and an Apple Developer account, which are parked.

## Run it on Windows

1. Install Flutter for Windows desktop by following https://docs.flutter.dev/platform-integration/windows/setup . You need Git for Windows and Visual Studio 2022 (not VS Code) with the "Desktop development with C++" workload. Then run `flutter doctor` in a terminal and fix anything it reports for Windows. Tested here with Flutter 3.47.9.
2. Copy the whole `bible-study\app` folder to the PC, keeping `app\data\build\bible.sqlite` (445 MB) where it is.
3. In a terminal (PowerShell or Command Prompt):

   ```
   cd bible-study\app\app
   flutter pub get
   flutter run -d windows
   ```

   If Flutter asks you to turn on Developer Mode (needed for plugins), open Settings, then System, then For developers, switch Developer Mode on, and run the command again.

4. For a version you can start without Flutter: `flutter build windows`. The program is then `build\windows\x64\runner\Release\bible_study.exe`. Keep the whole `Release` folder together.

The first build needs internet access once: `flutter pub get` fetches packages and the `sqlite3` package fetches its prebuilt SQLite library (with full text search) during the build. Running the app never uses the network.

## Where to put bible.sqlite

The app looks in this order and uses the first file it finds:

1. `--db=PATH` on the command line, for example `flutter run -d windows --dart-entrypoint-args=--db=D:\bible\bible.sqlite`, or `bible_study.exe --db=D:\bible\bible.sqlite`
2. The `BIBLE_DB` environment variable
3. `data\bible.sqlite` next to `bible_study.exe` (the Windows build copies `..\data\build\bible.sqlite` there for you)
4. `bible.sqlite` next to `bible_study.exe`
5. `%APPDATA%\BibleStudy\bible.sqlite`
6. `data\build\bible.sqlite` in the current folder or any folder above it

If none exists, the app shows every path it checked. It opens the file read only.

## Your notes

Notes are written to a separate `user.sqlite` in the app's support folder, under `%APPDATA%` on Windows. The exact path is shown under the notes box and in Sources and licences. `bible.sqlite` is never written to.

## What works

* Whole canon navigation: a book list (Old Testament, New Testament, deuterocanonical books), a chapter grid, previous and next chapter, and verse scrolling.
* One passage screen. The original language column is on the left and an English version beside it.
  * Old Testament: Hebrew (STEP TAHOT) right to left, with vowel points and accents exactly as stored. An optional Septuagint column (Brenton Greek, Swete, or Swete Old Greek) can be switched on.
  * New Testament: TAGNT words that are in NA28 (default), SBLGNT, Robinson Pierpont Byzantine 2018, or Nestle 1904.
  * Deuterocanonical books: Brenton Greek.
* English: any of the 34 English texts in the database. Berean Standard Bible is the default.
* Rows follow KJV verse numbers. Hebrew verses with different numbering (for example Malachi 3:19 to 24, which is Malachi 4:1 to 6 in English, and Psalm titles) are placed in the matching English row, using TAHOT's own alternative reference data, and labelled with their Hebrew number. Septuagint columns keep their own numbering and say so in the column header.
* Tap a Hebrew or Greek word (TAHOT, TAGNT, Byzantine, Nestle 1904) to see its transliteration, word gloss, lemma, morphology and Strong's numbers, with the entry from STEP TBESH or TBESG and from Open Scriptures Strong's. If an extended Strong's id is missing from the STEP lexicon, the panel says so and shows the base number entry. The panel also shows the word exactly as published, with its / and \ morpheme dividers.
* Cross references: each verse shows how many it has. Tap the count or the verse number to list them (OpenBible.info, ordered by votes, with a preview in your English version). Tap one to jump there.
* Notes stub: two separate tabs, "What the text says" and "Interpretation", saved per verse in user.sqlite. Notes never appear inside the Bible text.
* Larger and smaller text, settings remembered between runs, and a Sources and licences screen read from the database.

## Fonts

Bundled in `assets/fonts`: Ezra SIL 2.51 for Hebrew and Gentium 7.000 (the new name for Gentium Plus) for Greek and English, both under the SIL Open Font License, with their licence files. SBL fonts are not used. Details and checksums: `../LICENSES/fonts/README.md`.

## Checks on the build box (Linux)

* `flutter test` also unpacks the bundled phone database exactly as the phone does and checks it is byte identical to `bible.sqlite`. It runs checks against the real database: Hebrew text kept in its published order (byte check on Genesis 1:1), vowel points present, the Malachi mapping, Strong's lookups, cross references, the database being read only, and notes kept apart. All 8 pass.
* `tool/screenshots.sh` renders the Linux build on a virtual screen and saves the pictures in `../docs/screenshots`. `tool/click_test.sh` clicks a Hebrew word and a cross reference with real mouse input and captures the screen.

The Windows build has not been run yet, because this box is Linux. Rendering on Windows still needs to be confirmed on Matthew's PC.
