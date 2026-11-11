import 'fold_table.dart';

final _mark = RegExp(r'\p{Mn}', unicode: true);
final _wordChar = RegExp(r'[\p{L}\p{N}\p{Co}]', unicode: true);
final _hebrewLetter = RegExp(r'[\u05D0-\u05EA\uFB1D-\uFB4F]');
final _greekLetter = RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]');

/// Folds one character the same way pipeline/build.py folded verse text for verse_fts:
/// canonical decomposition, combining marks (Hebrew points and cantillation, Greek accents
/// and breathings, Latin accents) removed, lower case, final sigma as medial sigma.
String foldChar(int rune) {
  final c = String.fromCharCode(rune);
  if (_mark.hasMatch(c)) return '';
  return (foldTable[rune] ?? c).toLowerCase().replaceAll('\u03C2', '\u03C3');
}

/// The search key for [s]. The displayed text is never changed; this is only for matching.
String fold(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    b.write(foldChar(r));
  }
  return b.toString();
}

/// Folded text plus, for each folded UTF-16 unit, the offset of the original character it
/// came from, so a match in the folded text can be highlighted in the original.
class FoldedText {
  final String original;
  final String folded;
  final List<int> start; // folded index -> original start offset
  final List<int> end; // folded index -> original end offset (exclusive)
  FoldedText._(this.original, this.folded, this.start, this.end);

  factory FoldedText(String original) {
    final b = StringBuffer();
    final start = <int>[], end = <int>[];
    var i = 0;
    for (final r in original.runes) {
      final len = r > 0xFFFF ? 2 : 1;
      final f = foldChar(r);
      for (var k = 0; k < f.length; k++) {
        start.add(i);
        end.add(i + len);
      }
      b.write(f);
      i += len;
    }
    // Combining marks fold to nothing, so stretch each match to swallow the marks that follow
    // its last letter (a Hebrew vowel under the final consonant stays highlighted with it).
    for (var k = 0; k < end.length; k++) {
      var e = end[k];
      while (e < original.length &&
          _mark.hasMatch(String.fromCharCode(original.codeUnitAt(e)))) {
        e++;
      }
      end[k] = e;
    }
    return FoldedText._(original, b.toString(), start, end);
  }
}

bool isWordChar(String s, int i) =>
    i >= 0 && i < s.length && _wordChar.hasMatch(s[i]);

/// One parsed search term: a word, a word beginning (typed with *), or a quoted phrase.
class SearchTerm {
  final List<String> words; // folded
  final bool prefix; // last word may continue
  const SearchTerm(this.words, {this.prefix = false});
  bool get isPhrase => words.length > 1;
}

/// Splits typed text into terms. "quoted words" form a phrase, a trailing * matches word
/// beginnings, every other run of letters is one word. All terms must appear in the verse.
List<SearchTerm> parseQuery(String input) {
  final terms = <SearchTerm>[];
  final parts = input.split('"');
  for (var p = 0; p < parts.length; p++) {
    final inQuotes = p.isOdd && p < parts.length - 1;
    final words = <String>[];
    final prefixes = <bool>[];
    final f = fold(parts[p]);
    final buf = StringBuffer();
    void flush(bool star) {
      if (buf.isEmpty) return;
      words.add(buf.toString());
      prefixes.add(star);
      buf.clear();
    }

    for (var i = 0; i < f.length; i++) {
      if (isWordChar(f, i)) {
        buf.write(f[i]);
      } else {
        flush(f[i] == '*');
      }
    }
    flush(false);
    if (words.isEmpty) continue;
    if (inQuotes) {
      terms.add(SearchTerm(words, prefix: prefixes.last));
    } else {
      for (var w = 0; w < words.length; w++) {
        terms.add(SearchTerm([words[w]], prefix: prefixes[w]));
      }
    }
  }
  return terms;
}

/// FTS5 MATCH expression for [terms]. Every word is a quoted string, so nothing typed can be
/// read as FTS5 syntax.
String ftsExpression(List<SearchTerm> terms) => terms
    .map((t) {
      final q = '"${t.words.join(' ')}"';
      return t.prefix ? '$q*' : q;
    })
    .join(' AND ');

/// Ranges [start, end) in the original text to highlight for [terms].
List<(int, int)> highlightRanges(String text, List<SearchTerm> terms) {
  if (terms.isEmpty) return const [];
  final ft = FoldedText(text);
  final f = ft.folded;
  final hits = <(int, int)>[];
  for (final t in terms) {
    var from = 0;
    while (true) {
      final (i, end) = _findWords(f, t, from);
      if (i < 0) break;
      var j = end;
      if (t.prefix) {
        while (isWordChar(f, j)) {
          j++;
        }
      }
      hits.add((ft.start[i], ft.end[j - 1]));
      from = j;
    }
  }
  hits.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final h in hits) {
    if (merged.isNotEmpty && h.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, h.$2 > last.$2 ? h.$2 : last.$2));
    } else {
      merged.add(h);
    }
  }
  return merged;
}

/// Finds the words of [t] in folded text, separated by any non word characters, on word
/// boundaries. Returns the folded index of the first letter and the end of the last word
/// as typed, or (-1, -1).
(int, int) _findWords(String f, SearchTerm t, int from) {
  final first = t.words.first;
  var i = f.indexOf(first, from);
  while (i >= 0) {
    if (!isWordChar(f, i - 1)) {
      final end = _restMatches(f, t, i);
      if (end >= 0) return (i, end);
    }
    i = f.indexOf(first, i + 1);
  }
  return (-1, -1);
}

int _restMatches(String f, SearchTerm t, int i) {
  var pos = i;
  for (var w = 0; w < t.words.length; w++) {
    final word = t.words[w];
    if (!f.startsWith(word, pos)) return -1;
    pos += word.length;
    final last = w == t.words.length - 1;
    if (!(last && t.prefix) && isWordChar(f, pos)) return -1;
    if (!last) {
      if (pos >= f.length) return -1;
      while (pos < f.length && !isWordChar(f, pos)) {
        pos++;
      }
    }
  }
  return pos;
}

/// The script the user typed in, used to pick a sensible text to search.
enum Script { latin, hebrew, greek }

Script scriptOf(String s) {
  if (_hebrewLetter.hasMatch(s)) return Script.hebrew;
  if (_greekLetter.hasMatch(s)) return Script.greek;
  return Script.latin;
}
