import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../settings/text_styles.dart';
import 'search_repository.dart';
import 'search_text.dart';

/// Offline full text search. Pops with the [SearchHit] the user taps, so the reader can open it.
class SearchScreen extends StatefulWidget {
  final SearchRepository search;

  /// The translation searched by default, normally the English column of the reader.
  final Version initial;
  final String initialQuery;
  const SearchScreen({
    super.key,
    required this.search,
    required this.initial,
    this.initialQuery = '',
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const pageSize = 100;

  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  late Version _version = widget.initial;
  bool _all = false;
  Timer? _debounce;
  int _generation = 0;

  bool _busy = false;
  String? _error;
  String _note = '';
  List<SearchTerm> _terms = const [];
  List<SearchHit> _hits = const [];
  int _total = 0;
  List<Version>? _scope;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _run);
    setState(() {}); // text direction and clear button follow the typing
  }

  /// Picks what to search. Typing Hebrew or Greek while an English translation is chosen
  /// would find nothing, so the search moves to the original language texts and says so.
  (List<Version>?, String) _scopeFor(String text) {
    if (_all) return (null, '');
    final script = scriptOf(text);
    final s = widget.search;
    if (script == Script.hebrew && _version.language != 'hbo') {
      final heb = s.searchable.where((v) => v.language == 'hbo').toList();
      return (
        heb,
        'Hebrew letters typed, so this searches the Hebrew Old Testament. Vowel points are optional.',
      );
    }
    if (script == Script.greek && _version.language != 'grc') {
      final grc = s.searchable.where((v) => v.language == 'grc').toList();
      return (
        grc,
        'Greek letters typed, so this searches every Greek text. Accents and breathings are optional.',
      );
    }
    return ([_version], '');
  }

  Future<void> _run({bool more = false}) async {
    _debounce?.cancel();
    final text = _query.text;
    final terms = parseQuery(text);
    final gen = ++_generation;
    if (terms.isEmpty) {
      setState(() {
        _terms = const [];
        _hits = const [];
        _total = 0;
        _note = '';
        _error = null;
        _busy = false;
      });
      return;
    }
    final (scope, note) = more ? (_scope, _note) : _scopeFor(text);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.search.search(
        text,
        versions: scope,
        limit: pageSize,
        offset: more ? _hits.length : 0,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _terms = terms;
        _scope = scope;
        _note = note;
        _total = page.total;
        _hits = more ? [..._hits, ...page.hits] : page.hits;
        _busy = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _busy = false;
        _error = 'Search failed: $e';
      });
    }
  }

  TextDirection get _inputDirection => scriptOf(_query.text) == Script.hebrew
      ? TextDirection.rtl
      : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('search.field'),
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          textDirection: _inputDirection,
          style: TextStyles.forLanguage(switch (scriptOf(_query.text)) {
            Script.hebrew => 'hbo',
            Script.greek => 'grc',
            Script.latin => 'eng',
          }, 18).copyWith(height: 1.3, color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search words, "a phrase" or lov*',
            border: InputBorder.none,
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _query.clear();
                      _run();
                    },
                  ),
          ),
          onChanged: _changed,
          onSubmitted: (_) => _run(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  key: const Key('search.scope'),
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('This translation'),
                    ),
                    ButtonSegment(value: true, label: Text('All texts')),
                  ],
                  selected: {_all},
                  onSelectionChanged: (s) {
                    setState(() => _all = s.first);
                    _run();
                  },
                ),
                if (!_all)
                  DropdownButton<String>(
                    key: const Key('search.version'),
                    value: _version.code,
                    isDense: true,
                    items: [
                      for (final v in widget.search.searchable)
                        DropdownMenuItem(
                          value: v.code,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              v.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (code) {
                      final v = widget.search.searchable
                          .where((x) => x.code == code)
                          .firstOrNull;
                      if (v == null) return;
                      setState(() => _version = v);
                      _run();
                    },
                  ),
              ],
            ),
          ),
          if (_note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(_note, style: TextStyle(color: scheme.primary)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Text(
              _status(),
              key: const Key('search.status'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          const Divider(height: 1),
          Expanded(child: _results(scheme)),
        ],
      ),
    );
  }

  String _status() {
    if (_error != null) return _error!;
    if (_terms.isEmpty) {
      return _busy ? 'Searching...' : 'Works offline. Type at least one word.';
    }
    if (_total == 0) return _busy ? 'Searching...' : 'No verses found.';
    final where = _all
        ? 'all texts'
        : (_scope?.length == 1 ? _scope!.first.name : 'the original texts');
    final n = _total == 1 ? '1 verse' : '$_total verses';
    return '$n in $where';
  }

  Widget _results(ColorScheme scheme) {
    final showMore = _hits.length < _total;
    return ListView.separated(
      key: const Key('search.results'),
      itemCount: _hits.length + (showMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == _hits.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run(more: true),
                child: Text('Show more (${_total - _hits.length} left)'),
              ),
            ),
          );
        }
        final h = _hits[i];
        final ownNumbers = h.ref != Ref(h.book.id, h.chapter, h.verse);
        return ListTile(
          key: ValueKey('search.hit.$i'),
          title: Text(
            '${h.book.name} ${h.ref.chapter}:${h.ref.verse}'
            '${ownNumbers ? '  (Hebrew ${h.chapter}:${h.verse})' : ''}'
            '${_all || (_scope?.length ?? 1) > 1 ? '  ·  ${h.version.name}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Directionality(
              textDirection: h.version.rtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: SizedBox(
                width: double.infinity,
                child: Text.rich(
                  highlightSpan(
                    h.text,
                    _terms,
                    TextStyles.forLanguage(h.version.language, 16),
                    TextStyle(
                      backgroundColor: scheme.tertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          onTap: () => Navigator.of(context).pop(h),
        );
      },
    );
  }
}

/// The verse text with every match of [terms] styled with [match].
TextSpan highlightSpan(
  String text,
  List<SearchTerm> terms,
  TextStyle base,
  TextStyle match,
) {
  final ranges = highlightRanges(text, terms);
  final children = <TextSpan>[];
  var at = 0;
  for (final (s, e) in ranges) {
    if (s > at) children.add(TextSpan(text: text.substring(at, s)));
    children.add(TextSpan(text: text.substring(s, e), style: match));
    at = e;
  }
  if (at < text.length) children.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: base, children: children);
}
