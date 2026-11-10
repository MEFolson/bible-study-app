import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/user_repository.dart';

/// Notes stub. Observation and interpretation are kept in separate tabs and separate rows,
/// stored in user.sqlite, never in bible.sqlite, and never shown inside the Bible text.
class NotesPanel extends StatefulWidget {
  final UserRepository user;
  final Book book;
  final int chapter;
  final int? verse;
  final VoidCallback onSaved;
  const NotesPanel({
    super.key,
    required this.user,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.onSaved,
  });
  @override
  State<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<NotesPanel> {
  late final Map<String, TextEditingController> _c = {
    for (final k in UserRepository.kinds)
      k: TextEditingController(
        text: widget.verse == null
            ? ''
            : widget.user.note(
                widget.book.code,
                widget.chapter,
                widget.verse!,
                k,
              ),
      ),
  };
  String? _status;

  @override
  Widget build(BuildContext context) {
    final v = widget.verse;
    if (v == null)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Tap a verse number to write notes on it.'),
        ),
      );
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              '${widget.book.name} ${widget.chapter}:$v',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'What the text says'),
              Tab(text: 'Interpretation'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _editor(
                  'observation',
                  'Write only what the text itself says: words, grammar, repetition, structure.',
                ),
                _editor(
                  'interpretation',
                  'Your reading of what it means. Kept apart from your observations.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _status ??
                  'Saved in your own user.sqlite: ${widget.user.path}. The Bible text database is read only.',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editor(String kind, String hint) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(hint, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _c[kind],
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            widget.user.saveNote(
              widget.book.code,
              widget.chapter,
              widget.verse!,
              kind,
              _c[kind]!.text,
            );
            setState(() => _status = 'Saved.');
            widget.onSaved();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }
}
