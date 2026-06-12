# Decision Log / Project Memory

> A running record of decisions, why we made them, and open questions. Newest at top. Update this whenever a meaningful choice is made — it's the project's memory.

---

## 2026-06-12 — iOS/App Store strategy captured for future agent work

**Context:** Reviewed the actual repo state before planning iOS distribution. The app is Flutter-first, currently Windows-only at the platform layer, with no custom native iOS/macOS implementation yet.

**Decisions:**
1. **Treat iOS as platform expansion, not a C++ port.** The current codebase is mostly pure Dart/Flutter plus the generated Windows runner, so the first iOS work is adding `ios/` and `macos/` scaffolding, not rewriting native code.
2. **Capture iOS/App Store constraints in a root `CLAUDE.md`.** Future agent sessions should see the Apple review constraints, Kids Category tradeoffs, and repo-specific launch order without re-deriving them.
3. **Assume Kids Category constraints unless product positioning changes.** Current messaging presents SleepytimeApp as a children-focused bedtime app, so App Store work should be planned around parental gates, conservative data-sharing, and no casual analytics/ad SDK additions.
4. **Prefer a conservative first iOS release.** First release should stay local-only, avoid cloud accounts, keep BYO provider key setup in a parent-only area, and go through TestFlight before any hosted backend or billing work.

**Why:** The main risk for iOS is not native portability; it is App Store review, privacy disclosure, parental-gate design, and how third-party AI providers are used in a kids-oriented product.

**Affects:** `CLAUDE.md`, `build-plan/phase-5-polish-port.md`, iOS planning, future adapter work, App Store metadata/review notes.

**Open questions:**
- Final product positioning: strict Kids Category vs broader parent/family positioning.
- Whether BYO API keys survive the first public App Store version or become a TestFlight-only bridge.
- Exact parental-gate UX for settings, provider setup, outbound links, and any future purchases.

---

## 2026-06-12 — Project kickoff & foundational decisions

**Context:** Starting SleepytimeApp — a kids' nighttime storytelling app. PC-first, port to Mac/iOS. AI invents each night's chapter; voice reads it aloud.

**Decisions:**
1. **UI framework → Flutter.** One codebase Windows → macOS → iOS, great touch + theming. (Flutter/Dart not yet installed on this machine — Phase 0 task.)
2. **AI backend → multi-provider, BYO-key for dev, hosted-ready.** Claude/OpenAI/Gemini behind an `AiProvider` interface; Claude is the default for safety adherence. Architecture must allow a drop-in `HostedProvider` so this can become a billed product without touching the core. (User: *"setup for 2 and 3 — 2 for initial dev but the backend is built to switch to a hosted backend to make it a product."*)
3. **Data → local-only on device.** Privacy/COPPA-first; optional cloud sync deferred to Phase 6.
4. **Kickoff → repo + docs + phased build plan**, **plus** a designed-in **voice story reader**: male/female, multi-language, expressive character voices kids like. (User explicitly added this to the kickoff.)

**Architecture stance:** pure-Dart domain layer (story engine, prompt builder, safety guard, beat store) with swappable adapters (AI, TTS, STT, storage, secrets). Keeps logic testable and porting cheap. See [architecture.md](architecture.md).

**Safety stance:** four-layer defense (age policy injection → input guarding → output guardrail → continuity guard) with a never-break-bedtime fallback. See [safety.md](safety.md). This is the project's highest priority.

**Open questions to revisit:**
- Local DB: **Drift** (leaning) vs Isar — decide in Phase 2.
- Context window strategy (full recent beats + summarized history + story-bible) — tune against real token costs in Phase 2.
- Streaming generation + sentence-boundary TTS — nice-to-have, Phase 2/3.
- Character voice casting depth (pitch presets vs multi-voice cloud) — Phase 3.

**Repo:** `git init` on `main`, `core.autocrlf=true` (Windows). `.gitignore` blocks secrets, Flutter build artifacts, local data.

---

## 2026-06-12 — Feature & design refinements (review round)

**Context:** Reviewing the draft docs/quiz; user added several features and resolved parked decisions.

**Decisions:**
1. **Local DB → Drift (SQLite).** Series→beats, branching, and the archive are relational and need real queries + safe migrations. (Was leaning Drift; now locked.)
2. **Second-model safety reviewer → ON by default**, toggle in Settings (~2× cost; parent can disable).
3. **Hero choice → at new-series start**, not in the quiz. `Series.heroMode` = child-as-hero / named / surprise.
4. **Streaming generation → yes.** Stream story text; sentence-boundary hand-off to TTS in Phase 3.
5. **Story archive** — per-series list of past episodes (each with a `summary`), replayable via the voice reader (Phase 3).
6. **Story series + branching** — new `Series` entity; a child has multiple parallel storylines, can branch a new one (optionally forked from a beat via `branchedFromBeatId`). **Beats now belong to a series.** Drives a **story library** screen.
7. **Multi-user/multi-kid** — multi-kid already supported (many `ChildProfile`s/device). Multi-*parent* accounts deferred to hosted Phase 6.
8. **Adaptive/evolving quiz → yes.** Quiz `kind` = full / mini (per new series) / checkin (single refining Q). New `LearnedProfile` entity grows from play (twist picks, favorites, inferred interests) and feeds `PromptBuilder`; full re-quiz offered when the kid changes age band.

**Quiz changes:** added "stories/characters you already love" questions; banned **themes** moved to Settings (quiz only gives a soft hint).

**Parent's Brief:** new optional free-text field (on `ChildProfile`, optional per `Series`) for **values and tone** — the positive companion to the ban list. Injected into every prompt.

**Banned themes:** defaults pre-set per family — sex, drugs, alcohol, flirting, religion, evolution, birthdays, Christmas — plus a grouped menu of optional toggles (violence, death/grief, horror, occult/supernatural, other holidays, romance, real-world danger, crude/unkind, politics/gambling/etc.). Banned themes are a floor on top of the age band; stricter wins. See [safety.md](safety.md).

**Affects:** README, data-model.md (new Series + LearnedProfile entities, parentBrief, beat.seriesId), safety.md (banned themes menu, reviewer default, parent brief), architecture.md (SeriesService, LearnedProfile), ui-ux.md (library + archive screens), build-plan phases 1–3.

**Open questions:** twist deck = fixed categories with AI-flavored text (leaning); exact mini-quiz question set; confirm Drift schema v1 fields in Phase 2.

---

## 2026-06-12 — Series themes (chooser) + bilingual as a modifier

**Context:** Added a theme chooser when starting a new series — the series' overall *flavor*, distinct from the per-night twist deck. Then expanded the theme set and reclassified bilingual.

**Decisions:**
- **Full theme set (~16 + custom):** `adventure` · `technical` · `nature` · `documentary` · `learning` · `cozy` · `feelings` · `mystery` · `silly` · `fairytale` · `history` · `aroundTheWorld` · `superhero` · `mindfulness` · `sliceOfLife` · `surprise` · `custom` (+ `customTheme` free-text). Picked at new-series setup (theme → hero → mini-quiz). Chooser is **grouped** (Exciting / Calm & Bedtime / Discover & Learn / Imagine & Giggle / Surprise · Custom) so ~16 options aren't overwhelming.
- **Bilingual is a MODIFIER, not a theme** (user call). `bilingualEnabled` + `secondaryLanguage` + `bilingualBlend` (`sprinkle`/`phrases`/`alternating`) can layer onto *any* theme. Model emits **language-tagged spans**; voice reader switches language per span (cloud-TTS fallback where device lacks the 2nd voice).
- **Settings vs interests vs themes:** specific topics (pirates, space, dinosaurs) stay as **Interests/seed**, NOT themes, to keep the theme list broad (~16) and avoid sprawl.

**Why:** themes give a strong, predictable lever on tone/content; decoupling bilingual lets *every* flavor double as language practice. Theme sets series flavor; twist deck drives each episode within it.

**Affects:** README, data-model.md (Series.theme full enum + bilingual fields decoupled), ui-ux.md (grouped chooser + bilingual toggle), i18n.md + voice-tts.md (bilingual mode), build-plan phases 2–3. PromptBuilder golden-tested per theme + age band.

**Open questions:** exact prompt recipe per theme; bilingual correctness/age-appropriateness guardrails for the 2nd language; whether `bilingualBlend` auto-steps-up as the kid progresses; final emoji/icon set for theme cards.

---

## 2026-06-12 — Phase 0 complete (toolchain + skeleton + CI)

**Context:** Built the foundation so feature work can start.

**Environment / toolchain:**
- **Flutter 3.44.2 stable** installed via shallow `git clone` to `C:\src\flutter` (winget has no Flutter SDK package); added to user PATH. Dart 3.12.2.
- **No Visual Studio install needed:** the machine already had **Build Tools 2026** (and 2022) with the C++ desktop workload (MSVC `VC.Tools`, CMake, Windows 10 SDK). `flutter doctor` accepts Build Tools as a valid "Visual Studio" for Windows desktop. Android toolchain intentionally not installed (not a target).
- gh CLI 2.93.0 installed earlier, authed as `pixteur`; repo pushed.

**Scaffold decisions:**
- Project package name **`sleepytime`** (snake_case required), org **`com.pixteur`**, `--platforms windows` only for now (macOS/iOS added in Phase 5).
- State/DI: **Riverpod** wired at root (`ProviderScope`); `aiProvider` → `FakeAiProvider`, `storyEngineProvider` → `StoryEngine`.
- **Dependencies kept minimal:** only `flutter_riverpod` + `uuid` added now. Heavier deps (Drift, `flutter_secure_storage`, `flutter_tts`, `intl`/l10n, `freezed`) deferred to the phases that use them to avoid unused-package churn.
- Domain layer is pure Dart (no Flutter imports) — models + `StoryEngine`; adapters are interfaces with a `FakeAiProvider` so everything runs offline with no key.
- **CI** on GitHub Actions (ubuntu): `dart format --set-exit-if-changed` + `flutter analyze` + `flutter test`, Flutter pinned to 3.44.2.

**Verified:** `flutter analyze` clean · 5 tests pass · `flutter build windows --debug` → `sleepytime.exe` (1.2 MB).

**Affects:** new `lib/`, `test/`, `windows/`, `pubspec.yaml`, `.github/workflows/ci.yml`; build-plan README + phase-0 marked complete.

**Open questions:** revisit whether Build Tools (vs full VS) causes any issue when adding plugins with native code (none so far); confirm `freezed`/codegen approach when models gain (de)serialization in Phase 1.

---

## 2026-06-12 — Phase 1 complete (profiles, quiz, Drift)

**Context:** Built child accounts and the onboarding quiz on a real local database.

**Decisions / implementation:**
- **Drift schema v1** — `ChildProfiles`, `QuizResults`, `Interests`, `LearnedProfiles`. Enums stored via `intEnum`; `Map<String,String>` answers via a JSON `TypeConverter`; `LearnedProfile` as a JSON blob; FKs `onDelete: cascade`; `PRAGMA foreign_keys = ON`. `@DataClassName('…Row')` avoids collisions with the pure-domain models. Series/Beats come in Phase 2 (schema v2 migration).
- **DriftStorageRepo** implements the expanded `StorageRepo` port; all row↔domain mapping lives there so domain stays Drift-free.
- **Quiz** — 11 questions incl. "stories/characters you already love"; `deriveSeed`/`detailLevelFor` are **pure + unit-tested**; `submit` seeds `Interest`s (source=quiz) and sets detail level. Hero choice intentionally lives at new-series setup, not the quiz.
- **Parent gate** = randomized arithmetic speed-bump (not security). Skipped for the very first profile (nothing to protect yet).
- **Riverpod 3**: top-level `StateProvider` was removed → active child uses a `Notifier`/`NotifierProvider`.
- **Testing strategy**: domain tested against an **in-memory `StorageRepo`** (Drift's `NativeDatabase` needs native sqlite, not reliably present in `flutter test`). Drift itself verified by the **Windows build + runtime DB creation** (`Documents\sleepytime.sqlite`, 36 KB, schema built).
- **Generated code committed**: `.gitignore` no longer ignores `*.g.dart`/`*.freezed.dart`, so CI needs no `build_runner` step and the format check stays simple.

**Environment:** Enabling the SQLite plugin required **Windows Developer Mode** (symlink support) — enabled via an elevated registry write (user accepted UAC).

**Verified:** 13 tests pass · `flutter analyze` clean · `flutter build windows` OK · app boots and creates the DB.

**Affects:** `lib/adapters/storage/*`, `lib/domain/{profile_service,quiz_service}.dart` + new models, `lib/ui/{profiles,quiz,common,home}`, `app_providers.dart`, tests, `.gitignore`, build-plan.

**Open questions:** mini-quiz (per-series) question set; whether to add a Drift integration test on the windows device later; revisit `LearnedProfile` blob vs columns when the engine writes to it heavily in Phase 2.

---

## 2026-06-12 — Phase 2a complete (offline story engine)

**Context:** Built the heart of the app — the nightly story pipeline — fully offline against the FakeAiProvider first (per the agreed approach), so safety + continuity are nailed before spending API tokens.

**Implementation:**
- **Drift schema v2**: added `series` + `beats` tables (FKs cascade; enum via `intEnum`; `List<String>` via a JSON converter). v1→v2 `onUpgrade` migration **verified on the existing DB** (all 6 tables present at runtime).
- **Domain (pure, test-first):** `AgePolicy` (+ `BannedThemes.defaults`), `TwistDeck` (6 fixed cards + dice), `PromptBuilder`→`StoryPrompt` (single source of truth: age policy, banned themes, theme guidance, seed, story bible, interests, recent beats, intent line, bilingual), `SafetyGuard` (rating≤band, whole-word banned-theme scan, empty/flagged), `BeatStore` (recent window + nextSeq), `SeriesService` (create/list/archive/branch), `StoryEngine.takeTurn` (context→prompt→generate→safety→bounded retry→**safe fallback**→persist→LearnedProfile + story-bible update).
- **Interface change:** `AiProvider.generate(StoryPrompt)` — the engine builds the prompt; providers only translate + parse. FakeAiProvider returns a safe canned segment.
- **UI:** story library, new-series setup (grouped theme chooser + hero), series home (Continue/Roll/6 cards/type idea), story view.

**Key choices:**
- **Never break bedtime**: bounded retries then a pre-written safe fallback beat; provider errors are swallowed into the fallback.
- Banned themes default to the 8-item list (per-child settings UI deferred); injected into prompt AND enforced in the guard (floor on top of the age band).
- `HeroMode` collides with Flutter's `material.dart` export → `hide HeroMode` in the UI. Riverpod 3 AsyncValue uses `asData?.value` (not `valueOrNull`).
- Twist dice/option pass the twist *hint* as `chosenTwist` (good prompt); LearnedProfile keys affinity by it. Splitting tag-vs-hint is a 2b nicety.

**Verified:** 35 tests pass (incl. unsafe→fallback, error→fallback, adversarial safety) · `flutter analyze` clean · Windows build + migration + boot OK.

**Deferred to 2b:** real Claude/OpenAI/Gemini providers + structured output; `SecretStore`; **parent-gated** key Settings with third-party-AI **disclosure + consent** (per CLAUDE.md); streaming; per-child banned-themes UI; custom-theme/bilingual toggles in new-series; offline story bank.

**Affects:** `lib/adapters/storage/*` (schema v2), `lib/adapters/ai/*`, `lib/domain/{age_policy,twist_deck,prompt_builder,safety_guard,beat_store,series_service,story_engine}.dart`, `lib/ui/{series,story}`, `app_providers.dart`, tests, build-plan.

---

## 2026-06-12 — Phase 2b: real providers (Claude + OpenAI + Gemini), app icon

**Context:** Wired in real AI behind a parent-gated, consent-disclosed key screen, and added an app launch icon.

**Providers (all raw HTTP — no official Dart SDK — with structured output):**
- **ClaudeProvider** (default, `claude-opus-4-8`): `POST /v1/messages`, `output_config.format` JSON Schema. Consulted the `claude-api` skill for model id + structured-output approach.
- **OpenAiProvider** (`gpt-4o`): Chat Completions, `response_format.json_schema` (strict).
- **GeminiProvider** (`gemini-2.5-flash`): `generateContent`, `responseSchema` (Gemini's UPPERCASE dialect).
- Shared `story_segment_codec.dart` (JSON↔StorySegment + JSON Schema) and `provider_exceptions.dart` (NotConfigured / Refusal / RequestException). `AiProvider.generate` takes the built `StoryPrompt`.
- Provider switching: `aiConfigProvider` (Notifier) → the selected provider only when its key is stored AND `aiConsentGiven`; else the offline `FakeAiProvider`. Selection + consent in `AppPrefs` (shared_preferences); keys in `SecretStore`.

**Parent-gated Settings** (`lib/ui/settings`): provider picker, **third-party-AI disclosure + explicit consent checkbox**, key entry, real "Test connection", "Remove key" — reached via a gear behind `showParentGate`. Honors the `CLAUDE.md` requirements (parent-gated key entry, disclosure + consent before any data leaves the device; no telemetry of prompts/story text).

**Secure storage — DPAPI (not flutter_secure_storage):** the Windows impl of `flutter_secure_storage` requires the VS **ATL** C++ component, which wasn't installed and the VS-installer `modify` proved unreliable (and `vswhere` exits 0 even when a component is absent — a false-positive trap). Pivoted to `DpapiSecretStore` — `CryptProtectData`/`CryptUnprotectData` via FFI (crypt32.dll), encrypted blob in shared_preferences. **No admin, no ATL, per-user encryption.** Verified with a `@TestOn('windows')` round-trip test (CI on Linux skips it). macOS/iOS will add a Keychain-backed `SecretStore` later.

**App icon:** `app_icon.svg` / `app_icon.png` (1024) / `app_icon.ico` in the repo root — a cozy sleeping crescent moon on a night-sky squircle (app palette). Generator at `tools/make_icon.py` (Pillow). Wired into the Windows runner (`windows/runner/resources/app_icon.ico`); `flutter_launcher_icons` can generate macOS/iOS from the PNG later.

**Verified:** 43 tests pass (incl. provider parsing/refusal + DPAPI round-trip) · `flutter analyze` clean · Windows build OK · app boots.

**Open questions:** confirm exact current OpenAI model id for strict structured outputs (`gpt-4o` chosen); add OpenAI/Gemini refusal-shape coverage as we test live; revisit streaming.

---

## Template for new entries

```
## YYYY-MM-DD — <short title>
**Context:** …
**Decision:** …
**Why:** …
**Alternatives considered:** …
**Affects:** <docs/files>
**Open questions:** …
```
