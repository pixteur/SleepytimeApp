# Architecture

## Guiding principle

**Keep the story engine pure and the platform edges thin.** Everything that makes SleepytimeApp *work* (assembling prompts, enforcing safety, persisting beats) lives in plain Dart with no UI or platform dependencies. The UI, the AI network calls, the TTS, and the storage are all **swappable adapters** behind interfaces. That's what makes PC → Mac → iOS porting cheap, and what lets us flip from BYO-key to a hosted backend without touching the core.

```
┌──────────────────────────────────────────────────────────────┐
│  UI LAYER  (Flutter widgets — the only part that changes      │
│            meaningfully when porting to touch/iOS)            │
│  Home · Profiles · Quiz · StoryView · Settings · Interests   │
└───────────────────────────┬──────────────────────────────────┘
                            │ (state via Riverpod providers)
┌───────────────────────────┴──────────────────────────────────┐
│  APPLICATION / DOMAIN LAYER  (pure Dart — no Flutter)         │
│                                                              │
│   StoryEngine ──> PromptBuilder ──> [ AiProvider ] ──┐       │
│        │                                              │       │
│        │            ┌───────── SafetyGuard <──────────┘       │
│        │            ▼                                         │
│        └──> BeatStore (persist structured beats)             │
│                                                              │
│   ProfileService · InterestService · TwistDeck · Settings    │
└───────┬───────────────────┬───────────────────┬─────────────┘
        │                   │                   │
┌───────┴──────┐   ┌────────┴───────┐   ┌───────┴────────┐
│  AiProvider  │   │  TtsProvider   │   │  StorageRepo   │
│  interface   │   │  interface     │   │  interface     │
│ ┌──────────┐ │   │ ┌────────────┐ │   │ ┌────────────┐ │
│ │ Claude   │ │   │ │ DeviceTTS  │ │   │ │ Local DB   │ │
│ │ OpenAI   │ │   │ │ ElevenLabs │ │   │ │ (Drift/    │ │
│ │ Gemini   │ │   │ │ Azure/GCP  │ │   │ │  Isar)     │ │
│ │ Hosted * │ │   │ └────────────┘ │   │ │ Cloud  *   │ │
│ └──────────┘ │   └────────────────┘   │ └────────────┘ │
└──────────────┘                        └────────────────┘
        (* = future product phase, same interface)
```

## Layers

### 1. UI layer (`lib/ui/`)
Flutter widgets only. Talks to the domain layer through state providers — **never** calls an AI or storage adapter directly. Because logic lives below, porting to iOS touch is mostly re-laying-out screens, not rewriting behavior. Theming/color config lives here. See [ui-ux.md](ui-ux.md).

### 2. Domain layer (`lib/domain/`) — pure Dart, fully unit-testable
The brain. No `import 'package:flutter/...'`. Key pieces:

- **`StoryEngine`** — orchestrates a turn: gather context → build prompt → call provider → run SafetyGuard → persist beat → return result.
- **`PromptBuilder`** — turns (profile + interests + recent beats + chosen twist + language + detail level) into a structured prompt with system constraints. Single source of truth for "how we talk to the model."
- **`SafetyGuard`** — enforces age-appropriateness on every output (and validates inputs). See [safety.md](safety.md).
- **`TwistDeck`** — a deck of ~50 story openings; the creator draws a random hand of 6 as option cards, and the dice rolls across the whole deck. Tunable by parents.
- **`SeriesService`** — a child has many **series** (parallel storylines). Create / list (the **story library**) / continue / archive / **branch** (new series, optionally forked from a beat). Beats belong to a series.
- **`BeatStore`** — reads/writes structured story beats via the StorageRepo, scoped to a series. Handles "continue where we left off", the rolling per-series context window, and the **archive** (past episodes + summaries for replay).
- **`LearnedProfile`** — a living model updated each turn (twist picks, favorites, inferred interests) so stories improve without re-quizzing; feeds `PromptBuilder` as soft weights.
- **`ProfileService`, `InterestService`, `SettingsService`** — manage per-child data, incl. the **Parent's Brief** and **banned themes** that `PromptBuilder` injects.

### 3. Adapter layer (`lib/adapters/`) — the swappable edges
Each is an interface with multiple implementations selected at runtime:

- **`AiProvider`** — `Future<StorySegment> generate(StoryRequest req)`. Impls: Claude, OpenAI, Gemini, and a future `HostedProvider`. See [ai-providers.md](ai-providers.md).
- **`TtsProvider`** — `Future<void> speak(SpeakRequest req)`. Impls: device TTS (free/offline), cloud expressive voices. See [voice-tts.md](voice-tts.md).
- **`StorageRepo`** — local DB now; same interface backs optional cloud sync later. See [data-model.md](data-model.md).
- **`SttProvider`** — speech-to-text for the 🎤 "tell it what to hear" input.
- **`SecretStore`** — OS-secure storage for API keys (Windows Credential Manager / macOS Keychain / iOS Keychain).

## A story turn, step by step

```
User taps "Roll the dice" on Aiden's profile
   │
   ▼
StoryEngine.takeTurn(child: aiden, intent: DiceRoll)
   │  1. Load child profile + active interests + settings (language, detail level, age)
   │  2. BeatStore.recentContext(aiden)  → last N beats summarized
   │  3. TwistDeck.roll()                → a tone-appropriate twist
   │  4. PromptBuilder.build(...)        → system + user prompt with age constraints
   │  5. AiProvider.generate(request)    → StorySegment (text + self-reported rating + beat metadata)
   │  6. SafetyGuard.review(segment, childAge)
   │        ├─ pass  → continue
   │        └─ fail  → regenerate with tighter constraints (bounded retries) or fall back
   │  7. BeatStore.append(aiden, newBeat)
   │  8. TtsProvider.speak(segment, voice: aiden.preferredVoice, lang)
   ▼
StoryView renders text + plays narration; controls to pause/replay/stop
```

## State management

**Riverpod** for dependency injection + reactive UI state. It cleanly provides the right adapter implementations (e.g. swap Claude↔Gemini, DeviceTTS↔ElevenLabs) based on settings, and keeps the UI declarative. Domain services are exposed as providers; the UI watches them.

## Project structure (target)

```
lib/
  main.dart
  app.dart                  # MaterialApp, theming, routing
  ui/
    home/                   # launch screen: roll / continue / request
    profiles/               # create & pick child accounts
    quiz/                   # 10-question onboarding
    story/                  # StoryView + playback controls
    settings/               # per-child tuning, theme/color config
    interests/              # add/manage "new interests"
  domain/
    story_engine.dart
    prompt_builder.dart
    safety_guard.dart
    twist_deck.dart
    beat_store.dart
    models/                 # ChildProfile, Beat, Interest, StoryRequest, ...
    services/
  adapters/
    ai/                     # ai_provider.dart + claude/openai/gemini/hosted
    tts/                    # tts_provider.dart + device/cloud
    stt/
    storage/                # storage_repo.dart + local (Drift/Isar)
    secrets/
  l10n/                     # generated localizations (see i18n.md)
  theme/
test/
  domain/                   # the bulk of tests — pure, fast, no platform
assets/
  prompts/                  # versioned prompt templates
  twists/                   # twist-deck content (localizable)
```

## Why this shape

- **Testability** — the domain layer is pure Dart; the riskiest logic (prompting, safety, beat continuity) is covered by fast unit tests with fake providers, no network or device needed.
- **Portability** — only `lib/ui/` and a handful of adapters are platform-aware. iOS port ≈ touch layouts + iOS Keychain/TTS adapters.
- **Product-readiness** — flipping to a hosted backend is a new `AiProvider` impl + a `StorageRepo` that syncs; the core doesn't notice.

## Open questions / to revisit

- **Local DB:** Drift (SQL, mature, great query/migration story) vs Isar (fast NoSQL, simple). Leaning **Drift** for queryable beat history + migrations. Decide in Phase 2.
- **Streaming:** stream story text token-by-token for a "writing live" feel, and start TTS on sentence boundaries? Nice-to-have, revisit in Phase 2/3.
- **Rolling context strategy:** summarize-old-beats vs full-history-with-cache. See [data-model.md](data-model.md).
