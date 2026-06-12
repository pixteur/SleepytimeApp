# Build Plan

Phased roadmap for SleepytimeApp. Each phase is independently shippable-ish and builds on the last. The pure-Dart domain layer is built test-first; UI and adapters follow.

> Legend: 🟢 done · 🟡 in progress · ⚪ not started

| Phase | Title | Goal | Status |
|-------|-------|------|--------|
| 0 | [Foundation](phase-0-foundation.md) | Toolchain, Flutter project, architecture skeleton, CI | 🟢 |
| 1 | [Profiles & Quiz](phase-1-profiles-quiz.md) | Child accounts + onboarding quiz → story seed | 🟢 |
| 2 | [Story Engine](phase-2-story-engine.md) | The core loop: roll/continue/request → AI chapter → safe → saved | 🟢 |
| 3 | [Voice Reader](phase-3-voice-reader.md) | TTS narration, character voices, mic input | ⚪ |
| 4 | [i18n & Theming](phase-4-i18n-theming.md) | fr/es full, Japanese framework, color/theme personalization | ⚪ |
| 5 | [Polish & Port](phase-5-polish-port.md) | UX polish, macOS/iOS port, packaging | ⚪ |
| 6 | [Hosted Backend](phase-6-hosted-backend.md) | Turn it into a product: hosted provider, sync, billing, compliance | ⚪ |

## How we work

- **Domain logic is test-first.** The risky parts (prompting, safety, beat continuity) get unit tests with fake providers before/with the implementation.
- **Safety is never optional.** No generation feature merges without its safety tests (see [../docs/safety.md](../docs/safety.md)).
- **Document as we go.** Update [../docs/decision-log.md](../docs/decision-log.md) on every meaningful decision; keep the relevant doc in sync.
- **Vertical slices.** Prefer a thin end-to-end path working over a perfect single layer.

## Definition of "done" for a phase

1. Feature works end-to-end on Windows.
2. Domain logic covered by tests; `flutter analyze` clean.
3. Docs + decision log updated.
4. Committed with a clear message.

## Current focus

**Phase 3 — Voice Story Reader.** Phases 0–2 complete: the full nightly loop works with real AI (Claude / OpenAI / Gemini behind a parent-gated, consent-disclosed key screen; DPAPI-secured keys), offline fallback, and an app icon. 43 tests pass. Next: TTS narration (device + cloud), character voices, the story archive, and the 🎤 mic input. See [phase-3-voice-reader.md](phase-3-voice-reader.md).
