/// Finding a chapter's narration, in whichever voice it was saved with.
///
/// Narration is cached against the voice that spoke it — a different voice is
/// a different recording, so the key includes the voice signature. That is
/// right, and it has one bad consequence: changing voice makes every chapter
/// ever downloaded look like it was never downloaded. Nothing is deleted, and
/// 600 MB of it is still sitting on disk; the app simply stops asking for it.
///
/// A grown-up who switched from Gemini to ElevenLabs reads that as "the story
/// audio from last week is missing". So anything that only needs *a* recording
/// — the download badge, the exports, the storyteller — asks here, and gets
/// the current voice if it has one and any other saved voice if it does not.
///
/// Playback is the exception and does not use this: a story should be read in
/// the voice the grown-up chose, not in whichever one happens to be cached.
library;

import 'dart:typed_data';

import '../adapters/tts/audio_cache.dart';
import '../adapters/tts/narrated_chunks.dart';
import 'models/beat.dart';

/// A chapter's narration, and which voice recorded it.
class SavedTake {
  const SavedTake({required this.voiceSignature, required this.chunks});

  final String voiceSignature;

  /// The chapter's chunks in playback order, exactly as cached.
  final List<Uint8List> chunks;
}

/// Looks a chapter up across every voice this device has ever used.
class SavedNarration {
  const SavedNarration(this._cache);

  final AudioCache _cache;

  /// The chapter's recording in [preferred] if there is one, else in any of
  /// [alternatives], else null.
  ///
  /// A chapter counts as saved only when **every** chunk of it is there: half
  /// a chapter would export as a story that stops mid-sentence.
  Future<SavedTake?> find(
    Beat beat, {
    required String language,
    required String preferred,
    List<String> alternatives = const [],
  }) async {
    for (final voice in [preferred, ...alternatives]) {
      if (voice.trim().isEmpty) continue;
      final chunks = await _chunks(beat, voice, language);
      if (chunks != null) {
        return SavedTake(voiceSignature: voice, chunks: chunks);
      }
    }
    return null;
  }

  /// Whether a chapter is saved in any voice at all.
  Future<bool> isSavedAnywhere(
    Beat beat, {
    required String language,
    required String preferred,
    List<String> alternatives = const [],
  }) async =>
      await find(
        beat,
        language: language,
        preferred: preferred,
        alternatives: alternatives,
      ) !=
      null;

  Future<List<Uint8List>?> _chunks(
    Beat beat,
    String voiceSignature,
    String language,
  ) async {
    // Never build a key by hand: playback keys per chunk with the narration
    // cue mixed in, and this has to ask the same question the same way.
    final keys = chapterAudioKeys(
      voiceSignature: voiceSignature,
      language: language,
      text: beat.text,
      notes: beat.narration,
    );
    if (keys.isEmpty) return null;
    final parts = <Uint8List>[];
    for (final key in keys) {
      final bytes = await _cache.get(key);
      if (bytes == null || bytes.isEmpty) return null;
      parts.add(bytes);
    }
    return parts;
  }
}
