import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Android and iOS: bible.sqlite ships inside the app as gzip parts (assets/db, made by tool/pack_db.py).
/// On first launch, or after an app update that carries a different database, the parts are unpacked
/// once into the app's own storage. The copy is checked part by part (length and sha256) and is
/// only renamed into place when complete, so an interrupted copy is simply redone next launch.
/// The app then opens that copy read only. Nothing is downloaded.
class BundledDb {
  static const _dir = 'assets/db';

  static Future<String> ensure({
    void Function(double done, String message)? progress,
  }) async {
    // iOS: Library/Caches, so 445 MB that the app can recreate is not sent to iCloud backups (Apple's
    // storage guidance). If iOS ever clears it, the next launch simply unpacks it again.
    // Android: the app's private files folder. Notes (user.sqlite) stay in the support folder on both.
    final dir = Platform.isIOS
        ? await getApplicationCacheDirectory()
        : await getApplicationSupportDirectory();
    return unpack(
      manifestJson: await rootBundle.loadString('$_dir/manifest.json'),
      loadPart: (name) async {
        final b = await rootBundle.load('$_dir/$name');
        return b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
      },
      targetDir: dir,
      progress: progress,
    );
  }

  /// The copy itself, separate from Flutter assets so it can be tested on the build box.
  static Future<String> unpack({
    required String manifestJson,
    required Future<Uint8List> Function(String name) loadPart,
    required Directory targetDir,
    void Function(double done, String message)? progress,
  }) async {
    final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    final want = manifest['sha256'] as String;
    final total = manifest['bytes'] as int;
    await targetDir.create(recursive: true);
    final sep = Platform.pathSeparator;
    final db = File('${targetDir.path}${sep}bible.sqlite');
    final marker = File('${targetDir.path}${sep}bible.sqlite.ready');
    if (db.existsSync() &&
        marker.existsSync() &&
        marker.readAsStringSync().trim() == want &&
        db.lengthSync() == total) {
      return db.path;
    }
    final tmp = File('${targetDir.path}${sep}bible.sqlite.tmp');
    if (tmp.existsSync()) tmp.deleteSync();
    if (marker.existsSync()) marker.deleteSync();
    final parts = (manifest['parts'] as List).cast<Map<String, dynamic>>();
    final sink = tmp.openSync(mode: FileMode.writeOnly);
    var written = 0;
    try {
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i];
        progress?.call(
          written / total,
          'Preparing the Bible texts (one time only): part ${i + 1} of ${parts.length}',
        );
        final raw = gzip.decode(await loadPart(p['name'] as String));
        if (raw.length != p['raw_bytes'] ||
            sha256.convert(raw).toString() != p['raw_sha256']) {
          throw StateError('bundled database part ${p['name']} is damaged');
        }
        sink.writeFromSync(raw);
        written += raw.length;
        await Future<void>.delayed(
          Duration.zero,
        ); // let the progress screen repaint
      }
    } finally {
      sink.closeSync();
    }
    if (written != total)
      throw StateError('copied $written bytes, expected $total');
    if (db.existsSync()) db.deleteSync();
    tmp.renameSync(db.path);
    marker.writeAsStringSync(want);
    progress?.call(1, 'Ready');
    return db.path;
  }
}
