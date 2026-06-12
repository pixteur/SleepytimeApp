# Voice Story Reader (TTS)

The app reads each chapter aloud in an **expressive voice that can take on a character's personality** — male or female, kid-friendly, in the child's language. Like the AI layer, voice is **pluggable**: free/offline on-device for everyone, premium cloud voices for richer narration.

## The interface

```dart
abstract class TtsProvider {
  Future<void> speak(SpeakRequest req);   // narrate (may be streamed/segmented)
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<List<Voice>> availableVoices(Locale lang);
  Stream<SpeakProgress> get progress;     // for word/sentence highlighting
  TtsProviderId get id;                   // device | elevenlabs | azure | gcp | hosted
}

class Voice {
  final String id;
  final Gender gender;       // male | female | neutral
  final Locale language;
  final String displayName;  // kid-facing, e.g. "Captain Bramble"
  final bool expressive;     // supports emotion/character styling
}
```

## Providers

| Provider | Where it runs | Quality | Cost | Use |
|----------|---------------|---------|------|-----|
| **Device TTS** (`flutter_tts`) | On-device | Decent, robotic-ish | Free, offline | Default; first-run; offline; privacy |
| **ElevenLabs** | Cloud | Excellent, very expressive character voices | Paid (BYO key) | Premium "characters come alive" mode |
| **Azure Neural / Google Cloud TTS** | Cloud | Very good, many languages incl. Japanese | Paid (BYO key) | Strong multilingual alternative |
| **Hosted** (future) | Our backend | Curated voices | Bundled in subscription | Product phase |

All behind the same interface; selected in Settings. Device TTS guarantees the feature works for everyone with zero setup; cloud voices are an opt-in upgrade.

## Character voices — the magic

The goal: a story's characters don't all sound like one narrator. Approaches, increasing in sophistication:

1. **Per-child narrator voice** (MVP) — kid picks one male/female voice; whole story read in it.
2. **Pitch/rate styling per character** — device TTS supports pitch & rate; map recurring `characters` (from the beat metadata) to distinct pitch/speed presets so the giant sounds low and slow, the mouse high and quick. Cheap, works offline.
3. **Multi-voice casting** (cloud) — the AI already tags dialogue by character in the structured output; assign each recurring character a cloud voice and switch voices per line. This is where it really *sings*.
4. **Emotion/style tags** (cloud, ElevenLabs/Azure SSML) — pass tone hints ("gentle", "excited", "sleepy") so delivery matches the scene and winds down toward bedtime.

To enable casting, `PromptBuilder` asks the model to mark dialogue with speaker labels in the structured output; the TTS layer maps speakers → voices. Falls back gracefully to single-narrator if casting data is absent.

## Multi-language voices

- Voice list is filtered by the child's `language`.
- Device TTS language availability varies by OS — detect installed voices, prompt to install if missing, and fall back to a cloud provider for languages the device lacks (important for **Japanese** and less-common languages). See [i18n.md](i18n.md).

## Read-along (nice-to-have)

`progress` stream emits word/sentence boundaries → highlight text karaoke-style as it's read. Device TTS exposes progress handlers; cloud providers expose timestamps. Great for early readers; revisit after Phase 3 core works.

## Playback UX

Big, simple controls: ▶️ play/pause, ⏹ stop, 🔁 replay, a calm progress bar, and a sleep-friendly auto-dim. Touch-first sizing so it ports straight to iOS. Auto-lower volume / soften toward the end of a bedtime story.

## Failure handling

| Failure | Response |
|---------|----------|
| Cloud voice key missing/unreachable | Fall back to device TTS automatically |
| Language has no device voice | Prompt to install or use cloud; never silently fail |
| TTS engine error mid-story | Stop gracefully; text remains readable on screen |

## Phasing

Voice is **Phase 3** (after profiles, quiz, and the core story engine work). Device-TTS single-narrator first; character casting and cloud voices layered on. See [build-plan/phase-3-voice-reader.md](../build-plan/phase-3-voice-reader.md).
