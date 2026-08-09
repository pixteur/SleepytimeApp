/// Remove a pack directory that `.pi` does not list.
///
/// A write that fails partway leaves a complete or partial
/// `.content/<PACK>/` behind without ever touching `.pi`. The device cannot
/// see it — that is the whole point of writing `.pi` last — but it occupies
/// space, and `lunii_write` refuses to build over one.
///
/// **It will not remove a pack the device can see.** If `.pi` lists the
/// directory, this exits non-zero and does nothing; deleting installed content
/// is not what this is for, and the nine that shipped with a device are
/// purchased.
///
///     dart run tool/lunii_remove_orphan.dart F: 37804B72
///     dart run tool/lunii_remove_orphan.dart F:            # just list them
library;

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: lunii_remove_orphan.dart <drive> [PACK]');
    exitCode = 2;
    return;
  }
  final root = args.first;
  final pi = File('$root\\.pi').readAsBytesSync();
  final listed = <String>{
    for (var i = 0; i < pi.length; i += 16)
      pi
          .sublist(i + 12, i + 16)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(),
  };

  final content = Directory('$root\\.content');
  final onDisk =
      content
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(RegExp(r'[\\/]')).last)
          .toList()
        ..sort();
  final orphans = onDisk.where((d) => !listed.contains(d)).toList();

  if (args.length == 1) {
    stdout.writeln('${listed.length} listed in .pi, ${onDisk.length} on disk');
    stdout.writeln(
      orphans.isEmpty
          ? 'No orphans.'
          : 'Orphaned (invisible to the device): ${orphans.join(', ')}',
    );
    return;
  }

  final name = args[1].toUpperCase();
  if (listed.contains(name)) {
    stderr.writeln(
      '$name is listed in .pi — the device can see it. Refusing to remove '
      'installed content.',
    );
    exitCode = 1;
    return;
  }
  final dir = Directory('$root\\.content\\$name');
  if (!dir.existsSync()) {
    stderr.writeln('$name is not on the device');
    exitCode = 1;
    return;
  }

  final files = dir.listSync(recursive: true).whereType<File>().length;
  dir.deleteSync(recursive: true);
  stdout.writeln('Removed orphan $name ($files files).');
  stdout.writeln(
    '.pi untouched at ${File('$root\\.pi').lengthSync()} bytes '
    '(${listed.length} packs).',
  );
}
