/// Delete a story and its chapters by title. Intended for cleaning up a
/// refined copy so it can be regenerated; run with the app closed.
///
///     dart run tool/delete_series.dart "Obsidian Stone Refined"
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Pass the exact story title to delete.');
    exitCode = 2;
    return;
  }
  final title = args.first;
  final db = sqlite3.open(
    '${Platform.environment['USERPROFILE']}\\Documents\\sleepytime.sqlite',
  );
  // Chapters hang off the series by foreign key; without this they'd be left
  // behind as orphans.
  db.execute('PRAGMA foreign_keys = ON');

  final rows = db.select('select id from series where title = ?', [title]);
  if (rows.isEmpty) {
    stdout.writeln('No story titled "$title".');
    db.close();
    return;
  }
  for (final row in rows) {
    final id = row['id'];
    final beats = db.select(
      'select count(*) c from beats where series_id = ?',
      [id],
    ).first['c'];
    db.execute('delete from series where id = ?', [id]);
    stdout.writeln('Deleted "$title" ($id) and $beats chapters.');
  }
  db.close();
}
