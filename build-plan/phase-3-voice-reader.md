# Phase 3 — Voice Story Reader

**Goal:** Chapters are read aloud in expressive, kid-friendly voices that can take on character personalities — male/female, multi-language — plus the 🎤 microphone request path. See [../docs/voice-tts.md](../docs/voice-tts.md).

## 🟡 Status: Phase 3a + cloud voices COMPLETE (2026-06-12)

**Done:**
- **`TtsProvider`** interface (state stream + speak/pause/resume/stop) and **`DeviceTtsProvider`** via `flutter_tts` (Windows SAPI/WinRT, free/offline).
- **Cloud neural voices** (natural, the big quality jump): `CloudTtsProvider` + per-engine `TtsSynthesizer`s — **OpenAI** (`gpt-4o-mini-tts`), **ElevenLabs** (expressive/character), **Gemini** (`gemini-2.5-flash-preview-tts`, PCM→WAV). Audio played via `audioplayers`. Synthesizers are HTTP-only (unit-tested with mock client).
- **Voice setup screen** (parent-gated, via the 🔊 icon in Story AI setup): pick engine + voice, ElevenLabs key entry, "Save & test voice" preview. Cloud reuses the story keys + the same consent; falls back to device if no key/consent.
- **Story view narration**: auto-plays on open; playback bar (Read aloud / Pause / Resume / Stop) driven by the state stream; graceful error snackbar.
- **Story archive**: per-series past chapters with recaps (history icon); tap to re-read + replay.
- **Build notes:** `flutter_tts` needs **`nuget.exe`** on PATH (WinRT speech pkg); `audioplayers` provides Windows playback. Both installed/verified. CI (Linux analyze+test) unaffected.

**Deferred to Phase 3b:**
- Character voices (pitch/rate presets per recurring character; speaker-tagged dialogue → voice mapping); bilingual per-span narration; 🎤 **STT mic input**; read-along word highlighting; auto-soften toward the ending; per-child voice preference.

Original task checklist below for reference.

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

### Bilingual narration (Bilingual mode)
- [ ] Read language-tagged spans (from Phase 2) with **per-span voice/language switching**; prefer a voice covering both languages, else switch at boundaries. See [../docs/voice-tts.md](../docs/voice-tts.md).
- [ ] Cloud-TTS fallback when device lacks the 2nd language voice.

### Microphone input (🎤 request path)
- [ ] `SttProvider` impl (speech-to-text) + "hold to talk" UI with listening state + cancel.
- [ ] Route transcribed text through the **safety-guarded** request path (same as typed).
- [ ] Mic permission handling (per platform), fallback to typing.

### Story archive (replay past episodes)
- [ ] **Archive view** per series: list past `Beat`s with each `summary` (short "what happened").
- [ ] Tap any episode to **re-read or replay via the voice reader** (reuses narration above).
- [ ] Mark favorites (thumbs up) → feeds `LearnedProfile`.

### Read-along (nice-to-have)
- [ ] Word/sentence highlighting synced to `progress` stream (early-reader aid).
- [ ] Wire streaming generation (Phase 2) → sentence-boundary narration for a "live" read.

## Exit criteria
- A chapter is narrated aloud with at least pitch-differentiated character voices, controllable playback, in the child's language; cloud voices work when a key is provided and fall back cleanly when not.
- The 🎤 path produces a safe story from spoken input.

## Dependencies
- Phase 2 (beats carry character metadata; request path exists).

## Notes
- Japanese/less-common languages may need cloud TTS where device voices are missing — see [../docs/i18n.md](../docs/i18n.md).
- Keep all voice logic behind `TtsProvider`/`SttProvider` so iOS port swaps engines, not UI.
