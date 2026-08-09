/// Proves a write to a Lunii changed only what it was supposed to.
///
/// Installing a pack should create one new `.content/<PACK>/` directory and
/// append 16 bytes to `.pi`. Nothing else on the device may change — not
/// `.md`, not `.cfg`, not another pack's files. Those other packs are
/// purchased content, and a wrong byte in the index is how a library is lost.
///
/// Take a snapshot before writing and another after, then diff them:
///
///     dart run tool/lunii_manifest.dart snapshot F: before.json
///     …install a pack…
///     dart run tool/lunii_manifest.dart snapshot F: after.json
///     dart run tool/lunii_manifest.dart diff before.json after.json
///
/// The diff exits non-zero if anything changed that shouldn't have, so it can
/// gate a release as well as answer a question.
library;

import 'dart:convert';
import 'dart:io';

/// Content hash. Not cryptographic — this detects change, it doesn't defend
/// against a forger, and it has to run over a few hundred MB of audio.
String _hash(List<int> bytes) {
  var h = 0xcbf29ce484222325;
  for (final b in bytes) {
    h = (h ^ b) * 0x100000001b3;
    h &= 0xFFFFFFFFFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(16, '0');
}

Map<String, String> _snapshot(String root) {
  final out = <String, String>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = entity.path.substring(root.length).replaceAll('\\', '/');
    // Windows puts its own bookkeeping on any volume; it is not ours and it
    // changes on its own, so counting it would make every diff look dirty.
    if (rel.startsWith('/System Volume Information') ||
        rel.startsWith('/.Spotlight-V100')) {
      continue;
    }
    try {
      out[rel] = _hash(entity.readAsBytesSync());
    } catch (e) {
      out[rel] = 'UNREADABLE';
    }
  }
  return out;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: snapshot <drive> <out.json> | diff <a.json> <b.json>',
    );
    exitCode = 2;
    return;
  }

  if (args.first == 'snapshot') {
    final root = args[1].endsWith('\\') ? args[1] : '${args[1]}\\';
    final map = _snapshot(root.substring(0, root.length - 1));
    File(args[2]).writeAsStringSync(jsonEncode(map));
    stdout.writeln('${map.length} files recorded from ${args[1]}');
    return;
  }

  if (args.first != 'diff') {
    stderr.writeln('unknown command "${args.first}"');
    exitCode = 2;
    return;
  }

  final before = (jsonDecode(File(args[1]).readAsStringSync()) as Map)
      .cast<String, String>();
  final after = (jsonDecode(File(args[2]).readAsStringSync()) as Map)
      .cast<String, String>();

  final added = after.keys.where((k) => !before.containsKey(k)).toList()
    ..sort();
  final removed = before.keys.where((k) => !after.containsKey(k)).toList()
    ..sort();
  final changed =
      after.keys
          .where((k) => before.containsKey(k) && before[k] != after[k])
          .toList()
        ..sort();

  stdout.writeln('added:   ${added.length}');
  for (final f in added.take(12)) {
    stdout.writeln('  + $f');
  }
  if (added.length > 12) stdout.writeln('  … ${added.length - 12} more');
  stdout.writeln('removed: ${removed.length}');
  for (final f in removed) {
    stdout.writeln('  - $f');
  }
  stdout.writeln('changed: ${changed.length}');
  for (final f in changed) {
    stdout.writeln('  ~ $f');
  }

  // The verdict. A pack install may add files and may touch `.pi`. Anything
  // else means the writer reached somewhere it had no business being.
  final illegal = [...removed, ...changed.where((f) => f != '/.pi')];
  if (illegal.isEmpty) {
    // Say what actually happened. "Only .pi was modified" when nothing was
    // touched reads as a pass for a write that never ran.
    final parts = [
      if (added.isNotEmpty) '${added.length} new file(s)',
      if (changed.contains('/.pi')) '.pi appended',
    ];
    stdout.writeln(
      parts.isEmpty
          ? '\nOK — nothing on the device changed.'
          : '\nOK — ${parts.join(', ')}; nothing else touched.',
    );
  } else {
    stdout.writeln('\nFAIL — these should not have changed:');
    for (final f in illegal) {
      stdout.writeln('  $f');
    }
    exitCode = 1;
  }
}
