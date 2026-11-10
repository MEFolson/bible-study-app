import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/models.dart';

/// Whole canon: Old Testament, New Testament, and the deuterocanonical books held in the database.
class BookPicker extends StatefulWidget {
  final BibleRepository bible;
  final Version english;
  final Book current;
  const BookPicker({
    super.key,
    required this.bible,
    required this.english,
    required this.current,
  });
  @override
  State<BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<BookPicker> {
  Book? book;

  @override
  Widget build(BuildContext context) {
    final bible = widget.bible;
    final b = book;
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 640,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: b == null ? _books(bible) : _chapters(bible, b),
        ),
      ),
    );
  }

  Widget _books(BibleRepository bible) {
    final inEnglish = bible.booksOf(widget.english);
    Widget group(String title, String testament) {
      final list = bible.books
          .where(
            (x) =>
                x.testament == testament &&
                bible.chapterCount(x, widget.english) > 0,
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in list)
                ActionChip(
                  label: Text(
                    x.name,
                    style: TextStyle(
                      fontWeight: x.id == widget.current.id
                          ? FontWeight.bold
                          : null,
                      color: inEnglish.contains(x.id) ? null : Colors.black45,
                    ),
                  ),
                  onPressed: () => setState(() => book = x),
                ),
            ],
          ),
        ],
      );
    }

    return ListView(
      children: [
        const Text('Choose a book', style: TextStyle(fontSize: 20)),
        Text(
          'Grey names are not in ${widget.english.name}.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        group('Old Testament', 'OT'),
        group('New Testament', 'NT'),
        group('Deuterocanonical books', 'DC'),
      ],
    );
  }

  Widget _chapters(BibleRepository bible, Book b) {
    final n = bible.chapterCount(b, widget.english);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => book = null),
            ),
            Text(
              '${b.name}: choose a chapter',
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 12,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var c = 1; c <= n; c++)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, (b, c)),
                  child: Text('$c'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
