import '../../domain/models/narration.dart';

/// Playback state of the voice reader.
enum TtsState { idle, speaking, paused }

/// Voice gender preference (best-effort — device may not have both).
enum TtsGender { female, male, either }

/// Per-narration voice tuning. `pitch`/`rate` also drive simple character
/// voices (e.g. a low/slow giant, a high/quick mouse). See `docs/voice-tts.md`.
class TtsVoicePref {
  const TtsVoicePref({
    this.gender = TtsGender.either,
    this.pitch = 1.0,
    this.rate = 0.5,
  });

  final TtsGender gender;
  final double pitch; // ~0.5–2.0
  final double rate; // ~0.0–1.0

  TtsVoicePref copyWith({TtsGender? gender, double? pitch, double? rate}) =>
      TtsVoicePref(
        gender: gender ?? this.gender,
        pitch: pitch ?? this.pitch,
        rate: rate ?? this.rate,
      );
}

/// Swappable text-to-speech for the voice story reader. Device TTS (free,
/// offline) by default; expressive cloud voices as an opt-in upgrade later.
/// See `docs/voice-tts.md`.
abstract class TtsProvider {
  TtsProviderId get id;

  TtsState get state;
  Stream<TtsState> get stateStream;

  /// Fires ONLY when a chapter finishes reading naturally (not on stop/cancel),
  /// so auto-advance can't be triggered by a stop from leaving the screen.
  Stream<void> get onDone;

  /// Fraction (0.0–1.0) of the current chapter that has been read, for
  /// read-along scrolling + word highlighting. Best-effort; may stay at 0 for
  /// engines that don't report progress.
  Stream<double> get progressStream;

  /// Engine + voice id, used to locate this voice's cached audio (for .sleepy
  /// export) and to write imported audio back under the right key.
  String get voiceSignature;

  /// Container of the cached audio (`audio/wav` or `audio/mpeg`), so an
  /// audiobook export can join chapters correctly.
  String get audioMimeType;

  /// Narrate [text] in the given [language] (BCP-47-ish tag) with [voice].
  /// [notes] is how the chapter should be read — the standing voice plus a cue
  /// per paragraph. Engines that can't act on it ignore it; it never reaches
  /// the spoken text. See `docs/narration-cues.md`.
  Future<void> speak(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationNotes notes = const NarrationNotes(),
  });

  /// Warm the cache for [text] (e.g. the next chapter) WITHOUT playing it, so a
  /// page turn has no synthesis pause. No-op for engines that don't cache.
  Future<void> preload(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationNotes notes = const NarrationNotes(),
  }) async {}

  /// Whether [text] is already saved and would play without a network call.
  ///
  /// Only the provider can answer this: it alone knows how the chapter is split
  /// into chunks and how each one is keyed. Callers that rebuilt the key
  /// themselves got it wrong whenever a chapter spanned more than one chunk.
  /// Defaults to false — a live-only engine saves nothing.
  Future<bool> isCached(
    String text, {
    String language = 'en',
    NarrationNotes notes = const NarrationNotes(),
  }) async => false;

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

enum TtsProviderId { device, openai, elevenlabs, gemini, azure, gcp, hosted }
