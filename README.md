# SleepytimeApp

A kids' nighttime storytelling app. Each night you **seed a story**, then **roll the dice** or pick from **6 options**, and the app uses an AI model (Claude / OpenAI / Gemini) to invent the next chapter on the spot — read aloud in an expressive character voice.

Built **Flutter-first for PC (Windows)**, designed to port cleanly to **macOS and iOS** from a single codebase.

---

## What it does

- **Per-child accounts** (multi-kid) with an onboarding quiz — including stories they already love — that seeds each kid's story world.
- **Nightly launch choices:** 🎲 *Roll the dice* for a new twist, ▶️ *Continue where we left off*, or ⌨️/🎤 *Tell it what to hear* (text or microphone).
- **Multiple story series + branching** — keep several sagas going, or branch off a brand-new one (pick a **theme** and who the hero is).
- **~16 story themes** — Adventure, Mystery, Superhero, Cozy/Dreamtime, Mindfulness, Feelings & Kindness, Slice-of-Life, Nature, Technical, Documentary, Learning, History, Around the World, Fairytale, Silly, Surprise — plus a **Custom** free-text flavor.
- **Bilingual mode** — toggle on *any* story to weave in a second language and soak it up at bedtime.
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
- [CLAUDE.md](CLAUDE.md) — repo guidance for Claude/coding agents, including iOS/App Store constraints.

## Getting started (dev)

Flutter **3.44.2** is installed at `C:\src\flutter`. Requires Windows **Developer Mode** on (for plugin symlinks).

```powershell
flutter doctor          # verify toolchain
flutter pub get         # install dependencies
flutter run -d windows  # run the desktop app
```

> Generated code (`*.g.dart`) is committed. After changing Drift tables, regenerate with:
> `dart run build_runner build`
