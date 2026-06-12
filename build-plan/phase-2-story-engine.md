# Phase 2 — Story Engine (the core)

**Goal:** The nightly loop works end-to-end with a real AI provider: choose roll/continue/request → AI writes the next chapter → safety-checked → saved as a beat → displayed. **This is the heart of the app.**

## Tasks

### Domain (test-first)
- [ ] `PromptBuilder` — assembles system prompt (age policy + universal rules) + context (seed, recent beats, interests, chosen twist, language, detail level). Golden-snapshot tests per age band.
- [ ] `TwistDeck` — 6 localized option cards + `roll()`; parent-tunable tone. Content in `assets/twists/`.
- [ ] `BeatStore` — `recentContext(child)` (recent full beats + summarized history + story bible) and `append(beat)`. Tests for continuity assembly.
- [ ] `SafetyGuard.review()` — validates rating vs band, scans banned themes, enforces calm ending; bounded regenerate; safe-filler fallback. **Adversarial corpus tests (required).** See [../docs/safety.md](../docs/safety.md).
- [ ] `StoryEngine.takeTurn(child, intent)` — orchestrates the full step list from [../docs/architecture.md](../docs/architecture.md).

### Adapters — real AI
- [ ] Implement `ClaudeProvider` (default) with **structured output** (story_text + rating + flags + summary + characters + setting + open_threads). Consult the **claude-api** skill for model IDs/structured-output/caching.
- [ ] Implement `OpenAiProvider` and `GeminiProvider` to the same contract (can lag behind Claude).
- [ ] `SecretStore` real impl (Windows Credential Manager via `flutter_secure_storage`).
- [ ] Provider selection + key entry + "Test connection" in Settings.
- [ ] Offline pre-written fallback bank.

### UI
- [ ] **Home/launch** screen: Continue / 🎲 Roll / 6 cards / ⌨️ type request.
- [ ] **Story view**: render chapter, basic next/again controls (voice comes Phase 3).
- [ ] Loading/"the storyteller is thinking" state; graceful error states.

### Decisions to finalize here
- [ ] **Drift vs Isar** — commit and migrate stubs.
- [ ] Context-window tuning against real token costs/latency.
- [ ] Streaming generation? (optional this phase.)

## Exit criteria
- With a real Claude key, a child can roll/continue/type and get a fresh, **age-appropriate**, coherent chapter that's saved and continues correctly the next session.
- SafetyGuard adversarial tests pass; bedtime never crashes (all failure paths fall back).

## Dependencies
- Phases 0–1.

## Notes
- The 🎤 mic path can wait for Phase 3 (shares the request path).
- This phase is where most risk lives — invest in tests and the safety corpus.
