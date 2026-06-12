# SleepytimeApp

A kids' nighttime storytelling app. Each night you **seed a story**, then **roll the dice** or pick from **6 options**, and the app uses an AI model (Claude / OpenAI / Gemini) to invent the next chapter on the spot — read aloud in an expressive character voice.

Built **Flutter-first for PC (Windows)**, designed to port cleanly to **macOS and iOS** from a single codebase.

---

## What it does

- **Per-child accounts** (multi-kid) with an onboarding quiz — including stories they already love — that seeds each kid's story world.
- **Nightly launch choices:** 🎲 *Roll the dice* for a new twist, ▶️ *Continue where we left off*, or ⌨️/🎤 *Tell it what to hear* (text or microphone).
- **Multiple story series + branching** — keep several sagas going, or branch off a brand-new one (pick a **theme** and who the hero is).
- **Story themes** — Adventure · Technical · Nature · Documentary · Learning · **Multilanguage** (a bilingual story to soak up a second language) · Custom.
- **Story archive** — browse past episodes with short recaps and replay any of them aloud.
- **Adjustable detail levels** and **streaming** stories that appear as they're written.
- **Grows with your kid** — a settings page to tune details, age, and tone, plus a **learned profile** that adapts from how they play.
- **Age-appropriate & safe** — hard age-rating constraints, a parent **banned-themes** list, an optional **Parent's Brief** for values/tone, and a content guardrail (with a second-model reviewer on by default).
- **New Interests** — add a fresh fascination (fractals, Jupiter, dinosaurs…) and the app nudges future stories that way.
- **Voice story reader** — male/female expressive voices that take on each character's personality, in multiple languages.
- **Multi-language** — English, French, Spanish at launch; Japanese and more built into the framework.
- **Personalizable UI** — kid-friendly, touch-ready, with color/theme customization.

## Status

🟢 **Phase 0 — Foundation & planning.** No app code yet. See [build-plan/](build-plan/README.md).

## Key decisions (locked)

| Area | Choice |
|------|--------|
| UI framework | **Flutter** (Windows → macOS → iOS, one codebase) |
| AI compute | **Multi-provider BYO-key** (Claude default, + OpenAI/Gemini), behind an abstraction that can switch to a **hosted backend** later |
| Data | **Local-only on device** (privacy / COPPA-first); optional cloud sync later |
| Voice | **Pluggable TTS** — on-device for free/offline, cloud (e.g. ElevenLabs/Azure) for premium character voices |

## Documentation

- [docs/](docs/) — architecture, safety, data model, AI providers, voice, i18n, UI/UX, and a running decision log.
- [build-plan/](build-plan/README.md) — phased roadmap, Phase 0 → Phase 6.

## Getting started (dev)

> Flutter is **not yet installed** on this machine. Phase 0 covers setup. Once installed:

```powershell
flutter doctor          # verify toolchain
flutter pub get         # install dependencies
flutter run -d windows  # run the desktop app
```
