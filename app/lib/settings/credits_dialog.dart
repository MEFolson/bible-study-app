import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/user_repository.dart';

/// Credits and licences, read from the source table of bible.sqlite, plus the bundled fonts.
class CreditsDialog extends StatelessWidget {
  final BibleRepository bible;
  final UserRepository user;
  const CreditsDialog({super.key, required this.bible, required this.user});

  @override
  Widget build(BuildContext context) {
    final rows = bible.credits();
    return AlertDialog(
      title: const Text('Sources and licences'),
      content: SizedBox(
        width: 760,
        height: 560,
        child: ListView(
          children: [
            SelectableText(
              'Text database: ${bible.path}\nBuilt: ${bible.meta('built')}\nYour notes: ${user.path}',
              style: const TextStyle(fontSize: 12),
            ),
            const Divider(),
            for (final r in rows)
              ListTile(
                dense: true,
                title: Text('${r['name']}  (${r['licence_class']})'),
                subtitle: SelectableText('${r['credit']}\n${r['licence_url']}'),
              ),
            const Divider(),
            const ListTile(
              dense: true,
              title: Text(
                'Ezra SIL 2.51 font (SIL Open Font License 1.1; Hebrew layout code MIT)',
              ),
              subtitle: Text(
                'Copyright SIL International; Hebrew layout copyright Ralph Hancock and John Hudson. https://software.sil.org/ezra/',
              ),
            ),
            const ListTile(
              dense: true,
              title: Text(
                'Gentium 7.000 font, formerly Gentium Plus (SIL Open Font License 1.1)',
              ),
              subtitle: Text(
                'Copyright SIL Global. https://software.sil.org/gentium/',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
