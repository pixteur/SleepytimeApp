# Phase 2 — Story Engine (the core)

**Goal:** The nightly loop works end-to-end with a real AI provider: choose roll/continue/request → AI writes the next chapter → safety-checked → saved as a beat → displayed. **This is the heart of the app.**

## 🟡 Status: Phase 2a COMPLETE (2026-06-12) — offline engine; 2b = real providers

**Done (2a — full pipeline against the FakeAiProvider, all offline & tested):**
- **Drift schema v2** — `series` + `beats` tables (FKs, enum + JSON-list converters); v1→v2 migration verified on the existing DB (all 6 tables present at runtime).
- **Domain engine:** `AgePolicy` (band policies + universal rules + default banned themes), `TwistDeck` (6 cards + dice), `PromptBuilder` (system+user: age policy, banned themes, theme, seed, recent beats, interests, intent, bilingual), `SafetyGuard` (rating-vs-band, banned-theme scan, empty/flagged), `BeatStore` (recent context + seq), `SeriesService` (create/list/archive/branch), and `StoryEngine.takeTurn` (gather → prompt → generate → safety → bounded retry → **safe fallback** → persist beat → update LearnedProfile + story bible).
- **AiProvider** now takes a built `StoryPrompt` (engine owns PromptBuilder, the single source of truth).
- **UI:** story library, new-series setup (grouped theme chooser + hero pick), series home (Continue / Roll / 6 cards / type idea), story view (Continue). Navigation: profile → library → series → story.
- **Tests:** 35 pass — engine pipeline incl. **unsafe→fallback** and **error→fallback**, safety adversarial cases, prompt golden checks, twist/series. `flutter analyze` clean; Windows build + migration verified.

**Deferred to Phase 2b:**
- Real `ClaudeProvider` (default) + OpenAI/Gemini with structured output; `SecretStore` (Windows Credential Manager); **parent-gated** provider/key Settings screen with a **third-party-AI disclosure + consent** step (per `CLAUDE.md`).
- Streaming generation; per-child banned-themes/settings UI; custom-theme text + bilingual toggle in new-series setup; offline pre-written story bank.

Original task checklist below for reference.

## Tasks

### Domain (test-first)
- [ ] `SeriesService` — create/list/continue/archive series; **branch** (new series, optionally forked from a beat). Powers the **story list/library**.
- [ ] New-series setup: **grouped theme chooser** (~16 themes + custom free-text; see [../docs/ui-ux.md](../docs/ui-ux.md)) → then hero, then mini-quiz.
- [ ] Hero choice at series start (`heroMode`: child-as-hero / named / surprise) → into `PromptBuilder`.
- [ ] **Bilingual mode** (modifier on any theme): `bilingualEnabled` + `secondaryLanguage` + `bilingualBlend`; `PromptBuilder` emits language-tagged spans for voice switching (Phase 3). See [../docs/i18n.md](../docs/i18n.md).
- [ ] `PromptBuilder` — assembles system prompt (age policy + **banned themes** + **parent brief** + **series theme** + universal rules) + context (series seed, recent beats, interests, `LearnedProfile` weights, chosen twist, language(s), detail level). Golden-snapshot tests per age band **and per theme**.
- [ ] `TwistDeck` — fixed categories with AI-flavored text + `roll()`; parent-tunable tone. Content in `assets/twists/`.
- [ ] `BeatStore` — `recentContext(series)` (recent full beats + summarized history + per-series `storyBible`) and `append(beat)`. Tests for continuity assembly.
- [ ] `LearnedProfile` updates: record twist picks / feedback / inferred interests each turn.
- [ ] `SafetyGuard.review()` — validates rating vs band, scans banned themes, enforces calm ending; bounded regenerate; safe-filler fallback. **Adversarial corpus tests (required).** See [../docs/safety.md](../docs/safety.md).
- [ ] `StoryEngine.takeTurn(child, intent)` — orchestrates the full step list from [../docs/architecture.md](../docs/architecture.md).

### Adapters — real AI
- [ ] Implement `ClaudeProvider` (default) with **structured output** (story_text + rating + flags + summary + characters + setting + open_threads). Consult the **claude-api** skill for model IDs/structured-output/caching.
- [ ] Implement `OpenAiProvider` and `GeminiProvider` to the same contract (can lag behind Claude).
- [ ] `SecretStore` real impl (Windows Credential Manager via `flutter_secure_storage`).
- [ ] Provider selection + key entry + "Test connection" in Settings.
- [ ] Offline pre-written fallback bank.

### UI
- [ ] **Story list / library** screen: a child's series as shelf cards → continue, or **branch off** a new series (with hero choice).
- [ ] **Home/launch** screen: Continue / 🎲 Roll / 6 cards / ⌨️ type request.
- [ ] **Story view**: render chapter with **streaming** text as it writes; next/again controls (voice comes Phase 3).
- [ ] Loading/"the storyteller is thinking" state; graceful error states.

### Decisions to finalize here
- [x] **DB → Drift** (decided 2026-06-12). Implement schema + migration v1 (ChildProfile, Series, Beat, Interest, QuizResult, LearnedProfile, Settings).
- [ ] Context-window tuning against real token costs/latency.
- [x] **Streaming generation → yes.** Stream tokens to Story view; sentence-boundary hand-off prepared for Phase 3 TTS.

## Exit criteria
- With a real Claude key, a child can roll/continue/type and get a fresh, **age-appropriate**, coherent chapter that's saved and continues correctly the next session.
- SafetyGuard adversarial tests pass; bedtime never crashes (all failure paths fall back).

## Dependencies
- Phases 0–1.

## Notes
- The 🎤 mic path can wait for Phase 3 (shares the request path).
- This phase is where most risk lives — invest in tests and the safety corpus.
