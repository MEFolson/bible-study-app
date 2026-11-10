import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../settings/text_styles.dart';

const maqaf = '\u05BE';

class PassageRowView extends StatelessWidget {
  final PassageRow row;
  final Version? original, septuagint;
  final Version english;
  final double fontSize;

  /// Phone layout: cells one above another instead of side by side.
  final bool stacked;
  final bool selected, hasNote;
  final int? selectedWordId;
  final VoidCallback onVerseTap, onXrefTap;
  final ValueChanged<Word> onWordTap;

  const PassageRowView({
    super.key,
    required this.row,
    required this.original,
    required this.septuagint,
    required this.english,
    required this.fontSize,
    this.stacked = false,
    required this.selected,
    required this.hasNote,
    required this.selectedWordId,
    required this.onVerseTap,
    required this.onXrefTap,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: stacked ? 40 : 52,
                child: InkWell(
                  onTap: onVerseTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
                    child: Column(
                      children: [
                        Text(
                          row.verse == 0 ? 'title' : '${row.verse}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                            fontSize: 13,
                          ),
                        ),
                        if (hasNote)
                          Icon(
                            Icons.edit_note,
                            size: 16,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ...(() {
                final cells = <Widget>[
                  if (original != null) _cell(original!, row.original),
                  if (septuagint != null) _cell(septuagint!, row.septuagint),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _cell(english, row.english),
                      if (row.xrefCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: onXrefTap,
                              child: Text(
                                '${row.xrefCount} cross references',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ];
                return stacked
                    ? [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: cells,
                          ),
                        ),
                      ]
                    : [for (final c in cells) Expanded(child: c)];
              }()),
            ],
          ),
          const Divider(height: 1, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _cell(Version v, Cell? c) {
    final style = TextStyles.forLanguage(v.language, fontSize);
    final dir = v.rtl ? TextDirection.rtl : TextDirection.ltr;
    Widget body;
    if (c == null) {
      body = const Text('');
    } else if (c.words != null) {
      body = WordLine(
        words: c.words!,
        style: style,
        direction: dir,
        selectedId: selectedWordId,
        onTap: onWordTap,
      );
    } else if ((c.text ?? '').isEmpty) {
      body = Text(
        'No text for this verse number in this edition.',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: fontSize * 0.7,
          fontStyle: FontStyle.italic,
          color: Colors.black45,
        ),
      );
    } else {
      body = SelectableText(c.text!, textDirection: dir, style: style);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Directionality(
        textDirection: dir,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c?.ownRef != null)
              Text(
                '${v.language == 'hbo' ? 'Hebrew' : 'This edition'} ${c!.ownRef}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            body,
          ],
        ),
      ),
    );
  }
}

/// A verse of tagged words, each tappable. Shows word.text (the pipeline's display form) unchanged.
class WordLine extends StatefulWidget {
  final List<Word> words;
  final TextStyle style;
  final TextDirection direction;
  final int? selectedId;
  final ValueChanged<Word> onTap;
  const WordLine({
    super.key,
    required this.words,
    required this.style,
    required this.direction,
    required this.selectedId,
    required this.onTap,
  });
  @override
  State<WordLine> createState() => _WordLineState();
}

class _WordLineState extends State<WordLine> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final spans = <InlineSpan>[];
    for (final w in widget.words) {
      final r = TapGestureRecognizer()..onTap = () => widget.onTap(w);
      _recognizers.add(r);
      final sel = w.id == widget.selectedId;
      // Greek TAGNT words carry a paragraph sign; it is hidden on screen only. Hebrew is shown as stored.
      final shown = widget.direction == TextDirection.rtl
          ? w.text
          : w.text.replaceAll('\u00B6', '');
      spans.add(
        TextSpan(
          text: shown,
          recognizer: r,
          mouseCursor: SystemMouseCursors.click,
          style: sel ? TextStyle(backgroundColor: Colors.amber.shade200) : null,
        ),
      );
      // Hebrew words joined by maqaf are printed with no space after it.
      if (!w.text.endsWith(maqaf)) spans.add(const TextSpan(text: ' '));
    }
    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      textDirection: widget.direction,
    );
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }
}
