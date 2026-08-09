/// Build a pack from cached narration and put it on an attached storyteller.
///
/// **Dry run unless `--write` is given.** Without it this reports exactly what
/// would be created and touches nothing, which is how the first attempt at any
/// device should start.
///
///     dart run tool/lunii_write.dart --drive F: --chapters 3
///     dart run tool/lunii_write.dart --drive F: --chapters 3 --write
///
/// Audio comes from the app's own cache under `<Documents>/Sleepytime/audio`,
/// re-encoded to the 44.1 kHz mono MP3 the device plays. The picture is the
/// night-sky cover reduced to sixteen colours.
///
/// Take a manifest snapshot either side of a real write — that is what proves
/// nothing else moved:
///
///     dart run tool/lunii_manifest.dart snapshot F: before.json
///     dart run tool/lunii_write.dart --drive F: --write
///     dart run tool/lunii_manifest.dart snapshot F: after.json
///     dart run tool/lunii_manifest.dart diff before.json after.json
library;

import 'dart:io';

import 'package:sleepytime/adapters/audio/mp3_encoder.dart';
import 'package:sleepytime/adapters/export/cover_image.dart';
import 'package:sleepytime/adapters/lunii/device_pack.dart';
import 'package:sleepytime/adapters/lunii/device_writer.dart';
import 'package:sleepytime/adapters/tts/audio_compression.dart';

void main(List<String> args) {
  final drive = _option(args, '--drive') ?? 'F:';
  final wanted = int.parse(_option(args, '--chapters') ?? '3');
  final audioDir =
      _option(args, '--audio') ??
      '${Platform.environment['USERPROFILE']}\\Documents\\Sleepytime\\audio';
  final backupDir =
      _option(args, '--backup') ??
      '${Platform.environment['USERPROFILE']}\\Documents\\Sleepytime\\device-backup';
  final live = args.contains('--write');

  final device = LuniiDevice.open(drive);
  stdout.writeln(
    'Device $drive  firmware "${device.firmware}"  '
    '${device.packIds.length} packs installed',
  );
  stdout.writeln('  key verified against ${device.packDirectories.first}');

  if (!canEncodeMp3) {
    stderr.writeln('No MP3 encoder on this platform — see docs/lunii-sync.md');
    exitCode = 1;
    return;
  }

  // Real narration out of the app's cache, re-encoded to what the device takes.
  final chapters = <DevicePackChapter>[];
  final sources = Directory(audioDir).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in sources) {
    if (chapters.length >= wanted) break;
    final raw = decompressAudio(file.readAsBytesSync());
    if (raw.length < 12 || String.fromCharCodes(raw, 0, 4) != 'RIFF') continue;
    final mp3 = wavToLuniiMp3(raw);
    chapters.add(DevicePackChapter(audio: mp3));
    stdout.writeln(
      '  chapter ${chapters.length}: ${file.uri.pathSegments.last} '
      '→ ${(mp3.length / 1024).round()} kB',
    );
  }
  if (chapters.isEmpty) {
    stderr.writeln('No cached WAV narration found in $audioDir');
    exitCode = 1;
    return;
  }

  final pack = buildDevicePack(
    chapters: chapters,
    deviceKey: device.deviceKey,
    cover: nightSkyCoverIndexed(seed: 'Sleepytime'),
  );
  final plan = planWrite(device, pack);
  stdout.writeln('\nPack ${pack.directoryName}');
  stdout.writeln(plan.describe());
  for (final path in plan.files.keys.toList()..sort()) {
    stdout.writeln('    ${path.substring(device.root.length)}');
  }

  if (!live) {
    stdout.writeln('\nDRY RUN — nothing written. Add --write to install.');
    return;
  }

  stdout.writeln('\nBacking up .pi and .md to $backupDir');
  for (final saved in backupDeviceIndexes(device, backupDir)) {
    stdout.writeln('  $saved');
  }
  final written = writePack(device, pack, backupDirectory: backupDir);
  stdout.writeln(
    '\nWrote ${written.length} files. '
    '${device.packIds.length} packs → ${LuniiDevice.open(drive).packIds.length}',
  );
}

String? _option(List<String> args, String name) {
  final at = args.indexOf(name);
  return at >= 0 && at + 1 < args.length ? args[at + 1] : null;
}
