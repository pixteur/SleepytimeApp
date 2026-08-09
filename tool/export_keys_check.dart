/// Read-only: for one story, compare the audio-cache key the **exports** use
/// (whole chapter text) with the keys **playback** actually writes (one per
/// narrated chunk, cue mixed in). If they disagree, a fully-downloaded story
/// exports as "no narration saved yet".
///
///     dart run tool/export_keys_check.dart <seriesId> [voiceSignature] [lang]
library;

import 'dart:convert';
import 'dart:io';

import 'package:sleepytime/adapters/tts/narrated_chunks.dart';
import 'package:sleepytime/domain/models/narration.dart';
import 'package:sqlite3/sqlite3.dart';

/// Copy of `audioCacheKey` — importing it would drag in `audio_cache.dart`,
/// which imports path_provider and so can't be compiled by plain `dart run`.
String audioCacheKey(String input) {
  var hash = 0xcbf29ce484222325;
  for (final b in utf8.encode(input)) {
    hash = (hash ^ b) * 0x100000001b3;
  }
  return (hash & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}

/// Mirrors CloudTtsProvider._chunkText — the size-based splitter.
List<String> chunkText(String text, {int maxLen = 6000}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (trimmed.length <= maxLen) return [trimmed];
  final sentences = trimmed
      .replaceAll(RegExp(r'\n\s*\n'), ' ')
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  final out = <String>[];
  final buf = StringBuffer();
  for (final s in sentences) {
    if (buf.isNotEmpty && buf.length + s.length > maxLen) {
      out.add(buf.toString().trim());
      buf.clear();
    }
    buf.write('$s ');
  }
  if (buf.isNotEmpty) out.add(buf.toString().trim());
  return out.isEmpty ? [trimmed] : out;
}

void main(List<String> args) {
  final seriesId = args.isNotEmpty ? args.first : '';
  final voiceSig = args.length > 1
      ? args[1]
      : 'gemini/gemini-2.5-flash-preview-tts/Aoede';
  final lang = args.length > 2 ? args[2] : 'en';
  final home = Platform.environment['USERPROFILE'];
  final audioDir = Directory('$home\\Documents\\Sleepytime\\audio');

  final db = sqlite3.open(
    '$home\\Documents\\sleepytime.sqlite',
    mode: OpenMode.readOnly,
  );
  if (seriesId == 'all') {
    // Sweep every story: how many chapters would an export find audio for,
    // versus how many playback has actually cached.
    for (final s in db.select('select id, title from series')) {
      final rows = db.select(
        'select seq, story_text, narration_json from beats '
        'where series_id = ? order by seq',
        [s['id']],
      );
      var wholeHits = 0, chunkComplete = 0;
      for (final b in rows) {
        final text = b['story_text'] as String;
        final raw = (b['narration_json'] as String?) ?? '{}';
        final notes = NarrationNotes.fromJson(
          jsonDecode(raw.trim().isEmpty ? '{}' : raw) as Map<String, dynamic>,
        );
        if (File(
          '${audioDir.path}\\'
          '${audioCacheKey('$voiceSig|$lang|${text.trim()}')}',
        ).existsSync()) {
          wholeHits++;
        }
        final chunks = narratedChunks(text, notes, chunkText);
        final all = chunks.every(
          (c) => File(
            '${audioDir.path}\\'
            '${audioCacheKey('$voiceSig|$lang|${c.text}${c.cacheSuffix}')}',
          ).existsSync(),
        );
        if (all && chunks.isNotEmpty) chunkComplete++;
      }
      stdout.writeln(
        '${(s['title'] as String).padRight(24)} chapters=${rows.length}  '
        'playback-cached=$chunkComplete  export-would-find=$wholeHits',
      );
    }
    db.close();
    return;
  }
  final beats = db.select(
    'select seq, story_text, narration_json from beats '
    'where series_id = ? order by seq',
    [seriesId],
  );
  stdout.writeln('voice: $voiceSig   lang: $lang');
  stdout.writeln('cache: ${audioDir.path}\n');

  var exportable = 0;
  for (final b in beats) {
    final text = b['story_text'] as String;
    final raw = (b['narration_json'] as String?) ?? '{}';
    final notes = NarrationNotes.fromJson(
      jsonDecode(raw.trim().isEmpty ? '{}' : raw) as Map<String, dynamic>,
    );
    final seq = b['seq'];

    // What the exports look for.
    final wholeKey = audioCacheKey('$voiceSig|$lang|${text.trim()}');
    final wholeHit = File('${audioDir.path}\\$wholeKey').existsSync();
    if (wholeHit) exportable++;

    // What playback actually wrote.
    final chunks = narratedChunks(text, notes, chunkText);
    final chunkHits = [
      for (final c in chunks)
        File(
          '${audioDir.path}\\'
          '${audioCacheKey('$voiceSig|$lang|${c.text}${c.cacheSuffix}')}',
        ).existsSync(),
    ];

    stdout.writeln(
      'chapter ${seq + 1}: ${text.length} chars, '
      '${chunks.length} chunk(s), cues=${notes.cues.length}',
    );
    stdout.writeln('  export key $wholeKey  ${wholeHit ? "HIT" : "miss"}');
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      stdout.writeln(
        '  chunk ${i + 1}  ${audioCacheKey('$voiceSig|$lang|${c.text}${c.cacheSuffix}')}'
        '  ${chunkHits[i] ? "HIT" : "miss"}'
        '  suffix=${c.cacheSuffix.isEmpty ? "(none)" : c.cacheSuffix}',
      );
    }
  }
  stdout.writeln(
    '\nchapters an export would find audio for: $exportable/${beats.length}',
  );
  db.close();
}
