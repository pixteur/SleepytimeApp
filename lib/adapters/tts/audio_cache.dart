import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../storage/library_paths.dart';

/// Persists synthesized narration audio so a chapter never has to be re-fetched
/// from the cloud: replaying, paging back, or reopening a saved story all play
/// straight from disk (instant + gap-free, and no extra API cost). Keyed by a
/// stable content hash of the exact text + voice + language, so a voice change
/// or edited text naturally misses and re-synthesizes. See `docs/voice-tts.md`.
abstract class AudioCache {
  Future<Uint8List?> get(String key);
  Future<void> put(String key, Uint8List bytes);
}

/// Stable, dependency-free 64-bit FNV-1a hash of [input] as hex — used as the
/// cache filename. Must stay stable across runs (String.hashCode is not), so we
/// compute it by hand over the UTF-8 bytes.
String audioCacheKey(String input) {
  const int fnvOffset = 0xcbf29ce484222325;
  const int fnvPrime = 0x100000001b3;
  var hash = fnvOffset;
  for (final b in utf8.encode(input)) {
    hash = (hash ^ b) * fnvPrime; // 64-bit wraparound is intentional
  }
  // Drop the sign bit for a clean, positive hex string (63 bits is plenty of
  // entropy for a filename key).
  return (hash & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}

/// File-backed cache under the app-support directory. Safe to call before the
/// directory exists; failures degrade to "no cache" rather than breaking audio.
class FileAudioCache implements AudioCache {
  Directory? _dir;

  Future<Directory?> _ensureDir() async {
    if (_dir != null) return _dir;
    try {
      return _dir = await LibraryPaths.audio();
    } catch (_) {
      return null;
    }
  }

  File? _fileFor(Directory dir, String key) => File(p.join(dir.path, key));

  @override
  Future<Uint8List?> get(String key) async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    try {
      final f = _fileFor(dir, key)!;
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String key, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    final dir = await _ensureDir();
    if (dir == null) return;
    try {
      // Write to a temp file then rename, so a reader never sees a partial file.
      final tmp = File(p.join(dir.path, '$key.tmp'));
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(p.join(dir.path, key));
    } catch (_) {
      // best-effort; a cache miss just means we re-synthesize next time
    }
  }
}
