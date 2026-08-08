/// Splitting a chapter into synthesis chunks that respect narration direction.
///
/// Two forces pull opposite ways. The reader deliberately uses **a few sizeable
/// chunks** so each one's playback outlasts the next one's synthesis, which is
/// what hides a cloud voice's fixed per-request latency. But a narration cue
/// applies to a paragraph, and a cue can only be honoured if it maps onto a
/// whole request — you cannot change the voice halfway through one.
///
/// The hybrid rule: **a chunk boundary is forced only where the direction
/// actually changes.** Consecutive paragraphs sharing a cue are merged and then
/// handed to the ordinary size-based chunker, so a chapter narrated in one
/// voice throughout costs exactly what it costs today. Only a chapter that
/// genuinely shifts tone pays for the extra requests, and only at the points
/// where it shifts.
library;

import '../../domain/models/narration.dart';

/// One synthesis request: the text to speak and the direction to speak it in.
class NarratedChunk {
  const NarratedChunk(this.text, this.cue);

  final String text;
  final NarrationCue cue;

  /// Mixed into the audio-cache key. The cue changes the audio without
  /// changing a word of the text, so a key built from the text alone would
  /// replay the previous reading.
  String get cacheSuffix => cue.isEmpty ? '' : '|${cue.encode()}';

  @override
  String toString() => '${text.length} chars ${cue.isEmpty ? "-" : cue}';
}

/// Build the chunks for [text] under [notes].
///
/// [sizeChunker] is the reader's existing size-based splitter, applied within
/// each run of same-direction paragraphs.
List<NarratedChunk> narratedChunks(
  String text,
  NarrationNotes notes,
  List<String> Function(String) sizeChunker,
) {
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (paragraphs.isEmpty) return const [];

  // With no direction at all, this must behave exactly like the reader does
  // today — same chunks, same cache keys, same request count.
  if (notes.cues.every((c) => c.isEmpty)) {
    return [
      for (final chunk in sizeChunker(text)) NarratedChunk(chunk, notes.cueAt(-1)),
    ];
  }

  final out = <NarratedChunk>[];
  var runStart = 0;
  for (var i = 1; i <= paragraphs.length; i++) {
    final endOfRun =
        i == paragraphs.length ||
        notes.cueAt(i).encode() != notes.cueAt(runStart).encode();
    if (!endOfRun) continue;
    final run = paragraphs.sublist(runStart, i).join('\n\n');
    for (final chunk in sizeChunker(run)) {
      out.add(NarratedChunk(chunk, notes.cueAt(runStart)));
    }
    runStart = i;
  }
  return out;
}
