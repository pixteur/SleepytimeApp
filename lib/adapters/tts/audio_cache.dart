import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/library_paths.dart';
import 'audio_compression.dart';

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
      final dir = await LibraryPaths.audio();
      _dir = dir;
      unawaited(_migrateLegacy(dir)); // one-time, best-effort
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Bring across audio cached before the library move (from the old
  /// `<ApplicationSupport>/audio_cache`), so previously-downloaded chapters keep
  /// their "downloaded" badge and play offline. Idempotent; only copies what's
  /// missing.
  Future<void> _migrateLegacy(Directory newDir) async {
    try {
      final support = await getApplicationSupportDirectory();
      final old = Directory(p.join(support.path, 'audio_cache'));
      if (!await old.exists()) return;
      await for (final entity in old.list()) {
        if (entity is! File) continue;
        final target = File(p.join(newDir.path, p.basename(entity.path)));
        if (!await target.exists()) {
          await entity.copy(target.path);
        }
      }
    } catch (_) {
      // best-effort — a miss just means re-downloading that chapter
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
      final raw = await f.readAsBytes();
      // Transparently decompress (older uncompressed files pass straight through).
      return decompressAudio(raw);
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
      // Compress off the UI thread (delta-code + gzip; ~2× smaller for WAV).
      final packed = await Isolate.run(() => compressAudio(bytes));
      // Write to a temp file then rename, so a reader never sees a partial file.
      final tmp = File(p.join(dir.path, '$key.tmp'));
      await tmp.writeAsBytes(packed, flush: true);
      await tmp.rename(p.join(dir.path, key));
    } catch (_) {
      // best-effort; a cache miss just means we re-synthesize next time
    }
  }
}
