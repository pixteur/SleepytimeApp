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

  /// Narrate [text] in the given [language] (BCP-47-ish tag) with [voice].
  Future<void> speak(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
  });

  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

enum TtsProviderId { device, elevenlabs, azure, gcp, hosted }
