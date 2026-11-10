import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/models.dart';
import '../settings/text_styles.dart';

/// Strong's numbers and lexicon entries for one tapped word. Lexicon text is shown as data from its
/// named source; nothing is added to it.
class WordPanel extends StatelessWidget {
  final BibleRepository bible;
  final Word? word;
  final Version? version;
  const WordPanel({
    super.key,
    required this.bible,
    required this.word,
    required this.version,
  });

  static String plain(String? html) {
    if (html == null) return '';
    var s = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    s = s
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n');
    return s.trim();
  }

  @override
  Widget build(BuildContext context) {
    final w = word;
    final v = version;
    if (w == null || v == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tap a Hebrew or Greek word to see its Strong\'s number and lexicon entry.',
          ),
        ),
      );
    }
    final orig = TextStyles.forLanguage(v.language, 30);
    final dir = v.rtl ? TextDirection.rtl : TextDirection.ltr;
    final small = const TextStyle(fontSize: 12, color: Colors.black54);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          w.text,
          style: orig,
          textDirection: dir,
          textAlign: TextAlign.center,
        ),
        if (w.textSrc != w.text) ...[
          Text(
            'As published in ${v.name}, with morpheme dividers:',
            style: small,
          ),
          Text(
            w.textSrc,
            style: TextStyles.forLanguage(v.language, 20),
            textDirection: dir,
          ),
        ],
        const SizedBox(height: 8),
        _kv('Transliteration', w.translit),
        _kv('Word gloss', w.gloss),
        _kv('Lemma', w.lemma, style: TextStyles.forLanguage(v.language, 16)),
        _kv('Morphology', w.morph),
        _kv('Strong\'s', w.strongIds),
        if (w.editions != null) _kv('Editions', w.editions),
        _kv('Reference', '${w.chapter}:${w.verse}, word ${w.position}'),
        const Divider(),
        for (final id in w.strongs) ...[
          Text(
            id,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          ...() {
            final entries = bible.lookup(id);
            if (entries.isEmpty)
              return [Text('No lexicon entry for $id.', style: small)];
            return [
              for (final e in entries)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bible.sourceNames[e.source] ?? e.source,
                          style: small,
                        ),
                        if (e.baseOnly)
                          Text(
                            '$id is not in this lexicon; showing the entry for ${e.strong}.',
                            style: small.copyWith(color: Colors.brown),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (e.lemma != null)
                              Text(
                                e.lemma!,
                                style: TextStyles.forLanguage(
                                  id.startsWith('H') ? 'hbo' : 'grc',
                                  20,
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (e.translit != null)
                              Flexible(
                                child: Text(
                                  e.translit!,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (e.gloss != null)
                          Text(
                            e.gloss!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        if (e.morph != null) Text(e.morph!, style: small),
                        if (e.definition != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SelectableText(plain(e.definition)),
                          ),
                      ],
                    ),
                  ),
                ),
            ];
          }(),
        ],
      ],
    );
  }

  Widget _kv(String k, String? v, {TextStyle? style}) => v == null || v.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  k,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              Expanded(child: SelectableText(v, style: style)),
            ],
          ),
        );
}
