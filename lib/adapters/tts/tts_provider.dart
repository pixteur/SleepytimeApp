/// Swappable text-to-speech for the voice story reader. Device TTS (free,
/// offline) by default; expressive cloud voices as an opt-in upgrade.
/// Full interface (voices, progress, character casting) lands in Phase 3.
/// See `docs/voice-tts.md`.
abstract class TtsProvider {
  TtsProviderId get id;

  /// Narrate [text] in the given [language] (BCP-47-ish tag).
  Future<void> speak(String text, {String language = 'en'});

  Future<void> stop();
}

enum TtsProviderId { device, elevenlabs, azure, gcp, hosted }
