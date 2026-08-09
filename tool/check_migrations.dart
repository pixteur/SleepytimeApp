/// Guards the migration mistake that has already shipped twice.
///
/// Both times the symptom appeared far from the cause — a null-check crash
/// when drift mapped a row, and "no such column" on save — because a database
/// reached a version number without having taken every step that number
/// implies. In-memory tests cannot catch it: they go through `onCreate` and
/// always get every column.
///
/// So this checks the one thing that is checkable statically — that the
/// declared `schemaVersion` and the `if (from < N)` steps agree:
///
///   * the highest step matches `schemaVersion`, so a new step without a
///     version bump (or a bump with no step) fails here rather than on a
///     user's device;
///   * the steps run 2..N with no gaps, since a missing number means a
///     database at that version upgrades through nothing at all.
///
///     dart run tool/check_migrations.dart
library;

import 'dart:io';

void main() {
  final file = File('lib/adapters/storage/app_database.dart');
  if (!file.existsSync()) {
    stderr.writeln('check_migrations: ${file.path} not found');
    exitCode = 2;
    return;
  }
  final source = file.readAsStringSync();

  final declared = RegExp(
    r'int\s+get\s+schemaVersion\s*=>\s*(\d+)\s*;',
  ).firstMatch(source);
  if (declared == null) {
    stderr.writeln('check_migrations: no schemaVersion found');
    exitCode = 2;
    return;
  }
  final version = int.parse(declared.group(1)!);

  final steps =
      RegExp(
          r'if\s*\(\s*from\s*<\s*(\d+)\s*\)',
        ).allMatches(source).map((m) => int.parse(m.group(1)!)).toSet().toList()
        ..sort();

  final problems = <String>[];
  if (steps.isEmpty) {
    problems.add('no `if (from < N)` migration steps found');
  } else {
    if (steps.last != version) {
      problems.add(
        'schemaVersion is $version but the highest migration step is '
        '${steps.last} — a step without a bump never runs for existing '
        'databases, and a bump without a step skips the upgrade entirely',
      );
    }
    for (var v = 2; v <= version; v++) {
      if (!steps.contains(v)) {
        problems.add(
          'no `if (from < $v)` step — a database sitting at v${v - 1} '
          'upgrades through nothing',
        );
      }
    }
  }

  if (problems.isEmpty) {
    stdout.writeln(
      'migrations OK — schemaVersion $version, steps ${steps.join(", ")}',
    );
    return;
  }
  stderr.writeln('check_migrations FAILED:');
  for (final p in problems) {
    stderr.writeln('  - $p');
  }
  stderr.writeln(
    '\nSee the migrations trap in CLAUDE.md. Commit anyway with --no-verify.',
  );
  exitCode = 1;
}
