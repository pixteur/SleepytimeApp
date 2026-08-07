import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The `.sleepy` container: a zip holding `manifest.json` (story text +
/// metadata) plus one audio file per chapter. This is the on-disk, shareable
/// story format — text and narration travel together so a story can be
/// re-listened offline (and, later, shared with friends). See `docs/data-model.md`.
class SleepyArchive {
  const SleepyArchive({required this.manifest, required this.audio});

  final Map<String, dynamic> manifest;
  final Map<String, Uint8List> audio; // path in archive → bytes
}

/// Pack a manifest + audio files into `.sleepy` bytes.
Uint8List encodeSleepy(SleepyArchive data) {
  final archive = Archive();
  final manifestBytes = utf8.encode(jsonEncode(data.manifest));
  archive.addFile(
    ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
  );
  data.audio.forEach((name, bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

/// Read `.sleepy` bytes back into a manifest + audio files.
SleepyArchive decodeSleepy(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  Map<String, dynamic>? manifest;
  final audio = <String, Uint8List>{};
  for (final file in archive) {
    if (!file.isFile) continue;
    final content = Uint8List.fromList(file.content as List<int>);
    if (file.name == 'manifest.json') {
      manifest = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
    } else {
      audio[file.name] = content;
    }
  }
  if (manifest == null) {
    throw const FormatException(
      'Not a .sleepy file: manifest.json is missing.',
    );
  }
  return SleepyArchive(manifest: manifest, audio: audio);
}
