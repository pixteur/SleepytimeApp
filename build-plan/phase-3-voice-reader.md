# Phase 3 — Voice Story Reader

**Goal:** Chapters are read aloud in expressive, kid-friendly voices that can take on character personalities — male/female, multi-language — plus the 🎤 microphone request path. See [../docs/voice-tts.md](../docs/voice-tts.md).

## Tasks

### Narration (device TTS first — free/offline)
- [ ] Implement `DeviceTtsProvider` (`flutter_tts`): speak / pause / resume / stop, progress stream.
- [ ] Playback controls in Story view: ▶️ play/pause, ⏹ stop, 🔁 replay, progress bar, auto-dim.
- [ ] Per-child **preferred voice** (male/female) selection in Settings, filtered by language.
- [ ] Auto-soften/lower toward a bedtime ending.

### Character voices
- [ ] **Pitch/rate presets** per recurring character (from beat `characters` metadata) — giant = low/slow, mouse = high/quick. Works on device TTS, offline.
- [ ] `PromptBuilder` marks dialogue with speaker labels in structured output → TTS maps speaker → voice/preset.
- [ ] **Cloud casting (opt-in):** `ElevenLabsProvider` (and/or Azure/GCP) for expressive multi-voice + emotion/SSML. BYO key, behind the same `TtsProvider` interface.
- [ ] Graceful fallback: cloud → device single-narrator if no key/unreachable.

### Microphone input (🎤 request path)
- [ ] `SttProvider` impl (speech-to-text) + "hold to talk" UI with listening state + cancel.
- [ ] Route transcribed text through the **safety-guarded** request path (same as typed).
- [ ] Mic permission handling (per platform), fallback to typing.

### Read-along (nice-to-have)
- [ ] Word/sentence highlighting synced to `progress` stream (early-reader aid).

## Exit criteria
- A chapter is narrated aloud with at least pitch-differentiated character voices, controllable playback, in the child's language; cloud voices work when a key is provided and fall back cleanly when not.
- The 🎤 path produces a safe story from spoken input.

## Dependencies
- Phase 2 (beats carry character metadata; request path exists).

## Notes
- Japanese/less-common languages may need cloud TTS where device voices are missing — see [../docs/i18n.md](../docs/i18n.md).
- Keep all voice logic behind `TtsProvider`/`SttProvider` so iOS port swaps engines, not UI.
