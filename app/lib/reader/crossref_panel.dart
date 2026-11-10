import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/models.dart';

/// Cross references from the OpenBible.info table, ordered by their votes. Tap one to open that passage.
class CrossRefPanel extends StatelessWidget {
  final BibleRepository bible;
  final Ref? from;
  final Version english;
  final ValueChanged<Ref> onOpen;
  const CrossRefPanel({
    super.key,
    required this.bible,
    required this.from,
    required this.english,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final f = from;
    if (f == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Tap a verse number to see its cross references.'),
        ),
      );
    }
    final list = bible.crossRefs(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${bible.label(f)}: ${list.length} cross references (OpenBible.info)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final x = list[i];
              final preview = bible.verseText(english, x.to);
              return ListTile(
                dense: true,
                title: Text(bible.label(x.to, end: x.toEnd)),
                subtitle: preview == null
                    ? null
                    : Text(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Text(
                  '${x.votes} votes',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                onTap: () => onOpen(x.to),
              );
            },
          ),
        ),
      ],
    );
  }
}
