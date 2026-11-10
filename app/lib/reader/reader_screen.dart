import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/bible_repository.dart';
import '../data/models.dart';
import '../data/user_repository.dart';
import '../lexicon/word_panel.dart';
import '../notes/notes_panel.dart';
import '../settings/credits_dialog.dart';
import '../settings/launch_options.dart';
import 'book_picker.dart';
import 'crossref_panel.dart';
import 'passage_row.dart';

class ReaderScreen extends StatefulWidget {
  final BibleRepository bible;
  final UserRepository user;
  final LaunchOptions options;
  const ReaderScreen({
    super.key,
    required this.bible,
    required this.user,
    required this.options,
  });
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  BibleRepository get bible => widget.bible;
  UserRepository get user => widget.user;

  final _scaffold = GlobalKey<ScaffoldState>();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  ItemScrollController _scroll = ItemScrollController();

  late Book book;
  int chapter = 1;
  int? focusVerse;
  late Version english;
  late String otOriginal; // tahot or a Greek Septuagint text
  late String ntOriginal; // tagnt, sblgnt, byz-rp2018, nestle1904
  bool showLxx = false;
  String lxxCode = 'grcbrent';
  double fontSize = 18;

  List<PassageRow> rows = [];
  Word? selectedWord;
  Version? selectedWordVersion;
  int? selectedVerse;
  Set<int> noted = {};

  static const otOriginalChoices = ['tahot', 'grcbrent', 'swete'];
  static const ntOriginalChoices = [
    'tagnt',
    'sblgnt',
    'byz-rp2018',
    'nestle1904',
  ];
  static const lxxChoices = ['grcbrent', 'swete', 'swete-og'];

  @override
  void initState() {
    super.initState();
    final o = widget.options;
    final englishCode =
        o.english ??
        user.get('english') ??
        (bible.versionByCode.containsKey('engbsb') ? 'engbsb' : 'eng-kjv2006');
    english =
        bible.versionByCode[englishCode] ?? bible.versionByCode['eng-kjv2006']!;
    otOriginal =
        _valid(o.original, otOriginalChoices) ??
        _valid(user.get('ot_original'), otOriginalChoices) ??
        'tahot';
    ntOriginal =
        _valid(o.original, ntOriginalChoices) ??
        _valid(user.get('nt_original'), ntOriginalChoices) ??
        'tagnt';
    showLxx = o.lxx || user.get('show_lxx') == '1';
    lxxCode = _valid(user.get('lxx'), lxxChoices) ?? 'grcbrent';
    fontSize =
        double.tryParse(user.get('font_size') ?? '') ??
        ((Platform.isAndroid || Platform.isIOS) ? 16 : 18);
    book =
        bible.bookByCode[o.gotoBook ?? user.get('book') ?? 'GEN'] ??
        bible.books.first;
    chapter = o.gotoChapter ?? int.tryParse(user.get('chapter') ?? '') ?? 1;
    focusVerse = o.gotoVerse;
    _load();
    if (o.word != null && focusVerse != null) {
      final r = rows.where((r) => r.verse == focusVerse).firstOrNull;
      final ws = r?.original?.words;
      if (ws != null && o.word! >= 1 && o.word! <= ws.length) {
        selectedWord = ws[o.word! - 1];
        selectedWordVersion = originalVersion;
        selectedVerse = focusVerse;
      }
    }
    if (o.panel != null || o.word != null) {
      selectedVerse ??= focusVerse;
      _tabs.index = switch (o.panel) {
        'xref' => 1,
        'notes' => 2,
        _ => 0,
      };
    }
    if (o.dialog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (o.dialog == 'books') {
          showDialog(
            context: context,
            builder: (_) =>
                BookPicker(bible: bible, english: english, current: book),
          );
        }
        if (o.dialog == 'credits') {
          showDialog(
            context: context,
            builder: (_) => CreditsDialog(bible: bible, user: user),
          );
        }
      });
    }
    if (o.screenshot != null) _scheduleScreenshot(o.screenshot!);
  }

  String? _valid(String? v, List<String> allowed) =>
      v != null && allowed.contains(v) && bible.versionByCode.containsKey(v)
      ? v
      : null;

  Version? get originalVersion {
    if (book.isNT) return bible.versionByCode[ntOriginal];
    if (book.isOT) return bible.versionByCode[otOriginal];
    // Deuterocanon: the Septuagint is the original language witness held in the database.
    return bible.versionByCode['grcbrent'];
  }

  Version? get lxxVersion => book.isOT && showLxx && otOriginal == 'tahot'
      ? bible.versionByCode[lxxCode]
      : null;

  void _load() {
    final max = bible.chapterCount(book, english);
    if (max > 0 && chapter > max) chapter = max;
    if (chapter < 1) chapter = 1;
    rows = bible.passage(
      book: book.id,
      chapter: chapter,
      english: english,
      original: originalVersion,
      septuagint: lxxVersion,
    );
    noted = user.versesWithNotes(book.code, chapter);
    _scroll = ItemScrollController();
    user.set('book', book.code);
    user.set('chapter', '$chapter');
  }

  void goTo(Book b, int c, {int? verse}) {
    if (_scaffold.currentState?.isEndDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    setState(() {
      book = b;
      chapter = c;
      focusVerse = verse;
      selectedVerse = verse;
      selectedWord = null;
      _load();
    });
  }

  void _step(int delta) {
    final max = bible.chapterCount(book, english);
    var c = chapter + delta;
    var b = book;
    final idx = bible.books.indexOf(book);
    if (c < 1 && idx > 0) {
      b = bible.books[idx - 1];
      c = bible.chapterCount(b, english);
    } else if (c > max && idx < bible.books.length - 1) {
      b = bible.books[idx + 1];
      c = 1;
    }
    if (c < 1) c = 1;
    goTo(b, c);
  }

  void _scheduleScreenshot(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 2500));
      final boundary =
          screenshotKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: widget.options.pixelRatio,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      stdout.writeln('screenshot written: $path');
      exit(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orig = originalVersion;
    final lxx = lxxVersion;
    final initialIndex = focusVerse == null
        ? 0
        : rows
              .indexWhere((r) => r.verse == focusVerse)
              .clamp(0, rows.isEmpty ? 0 : rows.length - 1);
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      key: _scaffold,
      endDrawer: narrow
          ? Drawer(
              width: MediaQuery.sizeOf(context).width * 0.92 > 440
                  ? 440
                  : MediaQuery.sizeOf(context).width * 0.92,
              child: SafeArea(child: _sidePanel()),
            )
          : null,
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            IconButton(
              tooltip: 'Previous chapter',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _step(-1),
            ),
            TextButton.icon(
              icon: const Icon(Icons.menu_book),
              label: Text(
                '${book.name} $chapter',
                style: const TextStyle(fontSize: 20),
              ),
              onPressed: () async {
                final pick = await showDialog<(Book, int)>(
                  context: context,
                  builder: (_) =>
                      BookPicker(bible: bible, english: english, current: book),
                );
                if (pick != null) goTo(pick.$1, pick.$2);
              },
            ),
            IconButton(
              tooltip: 'Next chapter',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _step(1),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _versionMenu(
                    label: 'Original',
                    value: orig?.code,
                    choices: book.isNT
                        ? ntOriginalChoices
                        : (book.isOT ? otOriginalChoices : ['grcbrent']),
                    onChanged: (v) => setState(() {
                      if (book.isNT) {
                        ntOriginal = v;
                        user.set('nt_original', v);
                      } else if (book.isOT) {
                        otOriginal = v;
                        user.set('ot_original', v);
                      }
                      selectedWord = null;
                      _load();
                    }),
                  ),
                  if (book.isOT && otOriginal == 'tahot') ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Septuagint column'),
                      selected: showLxx,
                      onSelected: (s) => setState(() {
                        showLxx = s;
                        user.set('show_lxx', s ? '1' : '0');
                        _load();
                      }),
                    ),
                    if (showLxx)
                      _versionMenu(
                        label: 'Septuagint',
                        value: lxxCode,
                        choices: lxxChoices,
                        onChanged: (v) => setState(() {
                          lxxCode = v;
                          user.set('lxx', v);
                          _load();
                        }),
                      ),
                  ],
                  const SizedBox(width: 8),
                  _versionMenu(
                    label: 'English',
                    value: english.code,
                    choices: bible.englishVersions.map((v) => v.code).toList(),
                    onChanged: (v) => setState(() {
                      english = bible.versionByCode[v]!;
                      user.set('english', v);
                      _load();
                    }),
                  ),
                  IconButton(
                    tooltip: 'Smaller text',
                    icon: const Icon(Icons.text_decrease),
                    onPressed: () => _font(-1),
                  ),
                  IconButton(
                    tooltip: 'Larger text',
                    icon: const Icon(Icons.text_increase),
                    onPressed: () => _font(1),
                  ),
                  IconButton(
                    tooltip: 'Sources and licences',
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => CreditsDialog(bible: bible, user: user),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                if (!narrow) _headers(orig, lxx),
                if (!narrow) const Divider(height: 1),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(
                          child: Text(
                            'No text for this chapter in the chosen versions.',
                          ),
                        )
                      : ScrollablePositionedList.builder(
                          key: ValueKey(
                            '${book.code}.$chapter.${english.code}.${orig?.code}.${lxx?.code}.$fontSize',
                          ),
                          itemScrollController: _scroll,
                          initialScrollIndex: initialIndex,
                          itemCount: rows.length,
                          itemBuilder: (context, i) => PassageRowView(
                            row: rows[i],
                            original: orig,
                            septuagint: lxx,
                            english: english,
                            fontSize: fontSize,
                            stacked: narrow,
                            selected: rows[i].verse == selectedVerse,
                            hasNote: noted.contains(rows[i].verse),
                            selectedWordId: selectedWord?.id,
                            onVerseTap: () => setState(() {
                              selectedVerse = rows[i].verse;
                              if (_tabs.index == 0) _tabs.index = 1;
                              if (narrow) {
                                _scaffold.currentState?.openEndDrawer();
                              }
                            }),
                            onXrefTap: () => setState(() {
                              selectedVerse = rows[i].verse;
                              _tabs.index = 1;
                              if (narrow) {
                                _scaffold.currentState?.openEndDrawer();
                              }
                            }),
                            onWordTap: (w) => setState(() {
                              selectedWord = w;
                              selectedWordVersion = orig;
                              selectedVerse = rows[i].verse;
                              _tabs.index = 0;
                              if (narrow) {
                                _scaffold.currentState?.openEndDrawer();
                              }
                            }),
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (!narrow) ...[
            const VerticalDivider(width: 1),
            SizedBox(width: 400, child: _sidePanel()),
          ],
        ],
      ),
    );
  }

  void _font(double d) => setState(() {
    fontSize = (fontSize + d).clamp(12, 32);
    user.set('font_size', '$fontSize');
  });

  Widget _versionMenu({
    required String label,
    required String? value,
    required List<String> choices,
    required ValueChanged<String> onChanged,
  }) {
    final items = choices.where(bible.versionByCode.containsKey).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13)),
          DropdownButton<String>(
            value: items.contains(value) ? value : null,
            underline: const SizedBox(),
            items: [
              for (final c in items)
                DropdownMenuItem(
                  value: c,
                  child: Text(
                    _short(bible.versionByCode[c]!),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ],
      ),
    );
  }

  String _short(Version v) {
    final n = v.name;
    return n.length > 44 ? '${n.substring(0, 42)}...' : n;
  }

  Widget _headers(Version? orig, Version? lxx) {
    Widget h(String t, {String? note, TextAlign align = TextAlign.left}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t,
                  textAlign: align,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (note != null)
                  Text(
                    note,
                    textAlign: align,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ),
        );
    String? origNote;
    if (orig?.code == 'tahot') origNote = 'Right to left. Verse rows follow the English (KJV) numbers; the Hebrew number is shown where it differs.';
    if (orig?.code == 'tagnt') origNote = 'Words in NA28, from the TAGNT tagged text. Tap a word for its lexicon entry.';
    if (orig != null && orig.scheme == 'LXX') origNote = 'Septuagint numbering, which differs from the English in places (for example most Psalms).';
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 52),
          if (orig != null)
            h(
              orig.name,
              note: origNote,
              align: orig.rtl ? TextAlign.right : TextAlign.left,
            ),
          if (lxx != null)
            h(
              lxx.name,
              note: 'Septuagint numbering, not realigned: in Psalms and some other books it differs from the Hebrew and English.',
            ),
          h(
            english.name,
            note: bible.scheme(english) == 'Hebrew'
                ? 'Hebrew numbering in this edition, placed in rows by KJV number.'
                : (bible.scheme(english) == 'KJV'
                      ? null
                      : '${bible.scheme(english)} numbering, not realigned.'),
          ),
        ],
      ),
    );
  }

  Widget _sidePanel() {
    final ref = selectedVerse == null
        ? null
        : Ref(book.id, chapter, selectedVerse!);
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Word'),
            Tab(text: 'Cross references'),
            Tab(text: 'Notes'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              WordPanel(
                bible: bible,
                word: selectedWord,
                version: selectedWordVersion,
              ),
              CrossRefPanel(
                bible: bible,
                from: ref,
                english: english,
                onOpen: (r) =>
                    goTo(bible.bookById[r.book]!, r.chapter, verse: r.verse),
              ),
              NotesPanel(
                key: ValueKey('notes.${book.code}.$chapter.$selectedVerse'),
                user: user,
                book: book,
                chapter: chapter,
                verse: selectedVerse,
                onSaved: () => setState(
                  () => noted = user.versesWithNotes(book.code, chapter),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}
