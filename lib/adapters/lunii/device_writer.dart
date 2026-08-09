/// Puts a built pack onto an attached storyteller.
///
/// This is the only code in the app that writes to a device, and the nine
/// packs already on one are purchased content, so the order of operations is
/// the whole design:
///
/// 1. Refuse anything that does not look like a storyteller.
/// 2. Copy `.pi` and `.md` somewhere safe **before** touching a byte.
/// 3. Write the whole `.content/<PACK>/` tree, reading each file back.
/// 4. Only then append the uuid to `.pi`, and verify that too.
///
/// The order matters in one direction only. A pack that is fully written but
/// unlisted is invisible — harmless clutter. A pack that is listed but
/// half-written is a library that will not open. So `.pi` goes last, always.
///
/// `.cfg` holds the device's own settings and is never opened.
///
/// See [docs/lunii-sync.md](../../../docs/lunii-sync.md), and
/// `tool/lunii_manifest.dart`, which proves after the fact that a write
/// touched only what it should.
library;

import 'dart:io';
import 'dart:typed_data';

import 'device_pack.dart';
import 'lunii_cipher.dart';

class LuniiDeviceException implements Exception {
  const LuniiDeviceException(this.message);
  final String message;

  @override
  String toString() => 'LuniiDeviceException: $message';
}

/// Bytes per entry in `.pi` — one uuid per installed pack.
const int _packIdSize = 16;

/// Read a file, giving the drive a moment to wake if it has gone idle.
///
/// A storyteller that has been sitting attached and untouched fails its first
/// access with `ERROR_NO_SUCH_DEVICE` — the volume is listed, `Get-Volume`
/// reports its free space, and the very next read succeeds. It is the USB
/// bridge waking up, not a missing device, and it cost two aborted runs before
/// it was recognised.
///
/// Only reads retry. A write that fails is left to the caller: repeating one
/// blindly is how a half-written file becomes a twice-written one.
Uint8List _readWaking(File file, {int attempts = 3}) {
  for (var attempt = 1; ; attempt++) {
    try {
      return file.readAsBytesSync();
    } on FileSystemException catch (e) {
      if (attempt >= attempts || e.osError?.errorCode != 433) rethrow;
      sleep(const Duration(milliseconds: 300));
    }
  }
}

/// An attached storyteller, opened for reading.
class LuniiDevice {
  LuniiDevice._({
    required this.root,
    required this.deviceKey,
    required this.packIds,
    required this.firmware,
  });

  final String root;

  /// "Key B", derived from `.md`. A pack's `bt` is ciphered with this, which
  /// is what ties the pack to this one device.
  final List<int> deviceKey;

  /// The uuids in `.pi`, in order.
  final List<Uint8List> packIds;

  /// Contents of `version`, if the device has one.
  final String firmware;

  /// Directory names under `.content/`, derived from the ids.
  List<String> get packDirectories => [
    for (final id in packIds) _directoryName(id),
  ];

  /// Open [root] and check it really is a storyteller.
  ///
  /// Everything here is a read. The checks are deliberately fussy: the cost of
  /// being wrong about which drive this is falls on somebody's story library.
  static LuniiDevice open(String root) {
    final md = File(_join(root, '.md'));
    final pi = File(_join(root, '.pi'));
    final content = Directory(_join(root, '.content'));

    if (!md.existsSync() || !pi.existsSync() || !content.existsSync()) {
      throw LuniiDeviceException(
        '$root is not a storyteller: expected .md, .pi and .content/ at its '
        'root',
      );
    }
    final mdBytes = _readWaking(md);
    if (mdBytes.length < 0x200) {
      throw LuniiDeviceException(
        '.md is ${mdBytes.length} bytes; a storyteller\'s is at least 512',
      );
    }
    final piBytes = _readWaking(pi);
    if (piBytes.length % _packIdSize != 0) {
      throw LuniiDeviceException(
        '.pi is ${piBytes.length} bytes, not a whole number of '
        '$_packIdSize-byte pack ids',
      );
    }

    final ids = [
      for (var i = 0; i < piBytes.length; i += _packIdSize)
        Uint8List.sublistView(piBytes, i, i + _packIdSize),
    ];
    final versionFile = File(_join(root, 'version'));

    final device = LuniiDevice._(
      root: root,
      deviceKey: luniiDeviceKey(mdBytes),
      packIds: ids,
      firmware: versionFile.existsSync()
          ? versionFile.readAsStringSync().trim()
          : 'unknown',
    );
    device._checkDeviceKey();
    return device;
  }

  /// Prove the derived key before writing anything with it.
  ///
  /// `bt` is the head of the ciphered `ri`, ciphered again with the device
  /// key, so deciphering an existing pack's `bt` must reproduce its `ri`
  /// exactly. A wrong key here would produce a pack the device silently
  /// refuses, and this is the cheapest way to find out first.
  ///
  /// Only the overlap is compared. `bt` is always 64 bytes; a pack we wrote
  /// ourselves whose chapters share one cover has a 12-byte `ri` and the rest
  /// of `bt` is padding. Skipping those instead would quietly disable this
  /// check on precisely the packs this app produces.
  void _checkDeviceKey() {
    for (final pack in packDirectories) {
      final dir = _join(_join(root, '.content'), pack);
      final bt = File(_join(dir, 'bt'));
      final ri = File(_join(dir, 'ri'));
      if (!bt.existsSync() || !ri.existsSync()) continue;
      final plain = luniiDecipher(bt.readAsBytesSync(), deviceKey);
      final head = ri.readAsBytesSync();
      final shared = plain.length < head.length ? plain.length : head.length;
      if (shared == 0) continue;
      for (var i = 0; i < shared; i++) {
        if (plain[i] != head[i]) {
          throw LuniiDeviceException(
            'The device key derived from .md does not match pack $pack — '
            'refusing to write with it',
          );
        }
      }
      return; // one verified pack is enough
    }
  }

  bool hasPack(Uint8List uuid) =>
      packDirectories.contains(_directoryName(uuid));
}

/// What a write would do, before it does it.
class WritePlan {
  const WritePlan({
    required this.packDirectory,
    required this.files,
    required this.bytes,
    required this.packsBefore,
  });

  /// Absolute path of the `.content/<PACK>/` directory to be created.
  final String packDirectory;

  /// Absolute path → bytes, every file that will be created.
  final Map<String, Uint8List> files;
  final int bytes;
  final int packsBefore;

  String describe() =>
      'create $packDirectory\n'
      '  ${files.length} files, $bytes bytes\n'
      '  then append 16 bytes to .pi ($packsBefore packs → ${packsBefore + 1})';
}

/// Work out exactly which files a write would create. Touches nothing.
WritePlan planWrite(LuniiDevice device, DevicePack pack) {
  if (device.hasPack(pack.uuid)) {
    throw LuniiDeviceException(
      'Pack ${pack.directoryName} is already installed',
    );
  }
  final packDirectory = _join(
    _join(device.root, '.content'),
    pack.directoryName,
  );
  if (Directory(packDirectory).existsSync()) {
    throw LuniiDeviceException(
      '$packDirectory already exists, though .pi does not list it — clean it '
      'up by hand before writing',
    );
  }
  return WritePlan(
    packDirectory: packDirectory,
    files: {
      for (final entry in pack.files.entries)
        _join(packDirectory, entry.key.replaceAll('/', Platform.pathSeparator)):
            entry.value,
    },
    bytes: pack.byteCount,
    packsBefore: device.packIds.length,
  );
}

/// Copy `.pi` and `.md` into [backupDirectory] before anything is written.
///
/// `.pi` is the file whose loss costs the most and whose recovery is easiest —
/// it is a few hundred bytes. `.md` carries the device key, which cannot be
/// re-derived from anywhere else.
List<String> backupDeviceIndexes(LuniiDevice device, String backupDirectory) {
  Directory(backupDirectory).createSync(recursive: true);
  final saved = <String>[];
  for (final name in ['.pi', '.md']) {
    final source = File(_join(device.root, name));
    if (!source.existsSync()) continue;
    final target = File(
      _join(backupDirectory, name == '.pi' ? 'pi.bak' : 'md.bak'),
    );
    // Read through the wake retry rather than copySync: this is usually the
    // first real I/O of a session, so it is where an idle drive says
    // ERROR_NO_SUCH_DEVICE.
    final bytes = _readWaking(source);
    // Delete an old backup rather than overwrite it. An earlier version of
    // this copied the file, and copySync carries the source's attributes — so
    // the backup of a Hidden `.pi` was itself Hidden, and rewriting it hit the
    // very same CREATE_ALWAYS refusal, one level removed from the device.
    if (target.existsSync()) target.deleteSync();
    target.writeAsBytesSync(bytes, flush: true);
    saved.add(target.path);
  }
  if (saved.isEmpty) {
    throw const LuniiDeviceException(
      'Nothing was backed up — refusing to write',
    );
  }
  return saved;
}

/// Install [pack] on [device], following the order at the top of this file.
///
/// [backupDirectory] is not optional: the backup is what makes the rest of
/// this recoverable. Returns the paths written.
List<String> writePack(
  LuniiDevice device,
  DevicePack pack, {
  required String backupDirectory,
}) {
  final plan = planWrite(device, pack);
  backupDeviceIndexes(device, backupDirectory);

  // The content tree first, every file read back before moving on. A device
  // that fills up or unplugs mid-write leaves an unlisted directory, which is
  // inert.
  final written = <String>[];
  for (final entry in plan.files.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value, flush: true);
    final back = file.readAsBytesSync();
    if (back.length != entry.value.length) {
      throw LuniiDeviceException(
        '${entry.key} read back as ${back.length} bytes, wrote '
        '${entry.value.length}',
      );
    }
    for (var i = 0; i < back.length; i++) {
      if (back[i] != entry.value[i]) {
        throw LuniiDeviceException('${entry.key} read back changed at byte $i');
      }
    }
    written.add(entry.key);
  }

  // Only now does the pack become visible.
  //
  // This is a real append, not a rewrite. Two reasons, and either alone would
  // be enough. The existing ids are never held in memory and rewritten, so a
  // bug here cannot scramble the nine packs somebody paid for. And on the
  // device `.pi` carries the Hidden attribute, which makes Windows refuse the
  // CREATE_ALWAYS that writeAsBytes uses — "Access is denied" — while opening
  // an existing file to append is fine.
  final pi = File(_join(device.root, '.pi'));
  final before = pi.readAsBytesSync();
  final handle = pi.openSync(mode: FileMode.append);
  try {
    handle.writeFromSync(pack.uuid);
    handle.flushSync();
  } finally {
    handle.closeSync();
  }

  final after = Uint8List(before.length + _packIdSize)
    ..setRange(0, before.length, before)
    ..setRange(before.length, before.length + _packIdSize, pack.uuid);
  if (!_sameBytes(pi.readAsBytesSync(), after)) {
    throw LuniiDeviceException(
      '.pi did not read back as written. The backup in $backupDirectory is '
      'the original — restore it before unplugging.',
    );
  }
  written.add(pi.path);
  return written;
}

/// Uninstall a pack: drop it from `.pi`, then delete its files.
///
/// **The order is the reverse of [writePack], for the same reason.** Installing
/// writes the files first because "present but unlisted" is harmless; removing
/// unlists first because "listed but missing" is the state that breaks a
/// library. Both orders avoid the same bad half-way house from opposite sides.
///
/// This is also the only place `.pi` gets shorter. It is truncated through a
/// handle to the existing file rather than rewritten, because every file at a
/// storyteller's root is Hidden and Windows refuses to recreate one.
///
/// Returns the number of files deleted.
int removePack(
  LuniiDevice device,
  Uint8List uuid, {
  required String backupDirectory,
}) {
  if (!device.hasPack(uuid)) {
    throw LuniiDeviceException('Pack ${_directoryName(uuid)} is not installed');
  }
  backupDeviceIndexes(device, backupDirectory);

  final keep = device.packIds
      .where((id) => !_sameBytes(id, uuid))
      .toList(growable: false);
  if (keep.length != device.packIds.length - 1) {
    throw const LuniiDeviceException(
      '.pi does not hold exactly one copy of that pack — refusing to guess',
    );
  }
  final rebuilt = Uint8List(keep.length * _packIdSize);
  for (var i = 0; i < keep.length; i++) {
    rebuilt.setRange(i * _packIdSize, (i + 1) * _packIdSize, keep[i]);
  }

  final pi = File(_join(device.root, '.pi'));
  final handle = pi.openSync(mode: FileMode.append);
  try {
    // Truncate to nothing, then append: in append mode every write lands at
    // the end, and after the truncate the end is the beginning.
    handle.truncateSync(0);
    handle.writeFromSync(rebuilt);
    handle.flushSync();
  } finally {
    handle.closeSync();
  }
  if (!_sameBytes(pi.readAsBytesSync(), rebuilt)) {
    throw LuniiDeviceException(
      '.pi did not read back as written. The backup in $backupDirectory is '
      'the original — restore it before unplugging.',
    );
  }

  final dir = Directory(
    _join(_join(device.root, '.content'), _directoryName(uuid)),
  );
  if (!dir.existsSync()) return 0;
  final count = dir.listSync(recursive: true).whereType<File>().length;
  dir.deleteSync(recursive: true);
  return count;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _directoryName(Uint8List uuid) => uuid
    .sublist(uuid.length - 4)
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join();

/// Join two path segments.
///
/// A bare drive letter needs the separator, not to be spared it: `F:` + `.md`
/// as `F:.md` is *drive-relative*, resolving against whatever the current
/// directory on F: happens to be. It reads as absolute and behaves as absolute
/// right up until something has changed that directory.
String _join(String a, String b) => a.endsWith(Platform.pathSeparator)
    ? '$a$b'
    : '$a${Platform.pathSeparator}$b';
