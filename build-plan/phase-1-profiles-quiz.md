# Phase 1 — Profiles & Quiz

**Goal:** Create per-child accounts and run the onboarding quiz that produces a story **seed**. All persisted locally.

## ✅ Status: COMPLETE (2026-06-12)

- **Drift (SQLite) schema v1** — `ChildProfiles`, `QuizResults`, `Interests`, `LearnedProfiles` (FKs + JSON converters); `DriftStorageRepo` maps rows↔pure domain models. DB opens + creates schema on Windows at runtime (verified: `Documents\sleepytime.sqlite`).
- **Profiles** — `ProfileService` CRUD; multi-kid **profile select** screen (avatar cards), **create-profile** form (name/age/colour/parent brief), behind a **parent gate** (arithmetic speed-bump).
- **Quiz** — 11-question `fullQuiz` incl. "stories/characters you already love"; one-question-per-screen UI; pure `deriveSeed` + `detailLevelFor`; `submit` persists the result, seeds `Interest`s, sets the profile's detail level.
- **Adaptive scaffold** — `QuizKind` (full/mini/checkin) + `LearnedProfile` model & persistence (populated from Phase 2).
- **Hero choice deliberately deferred to new-series setup** (Phase 2), per design.
- **13 tests pass** (profile + quiz services against an in-memory `StorageRepo`, boot smoke); `flutter analyze` clean; Windows build OK.

**Notes:** Riverpod 3 removed top-level `StateProvider` → used a `Notifier` for the active child. Domain tests run against an in-memory repo (Drift's native sqlite isn't reliably loadable in `flutter test`); the real Drift path is verified by the Windows build + runtime DB creation. Generated `*.g.dart` is committed so CI needs no codegen step.

Original task checklist below for reference.

## Tasks

### Child profiles
- [ ] Implement `StorageRepo` (local DB) for `ChildProfile` CRUD.
- [ ] `ProfileService` (domain) — create/list/update/delete, set active child.
- [ ] **Profile select** screen — avatar cards, "add child".
- [ ] **Create/edit profile** (gated for parents) — nickname, avatar, age, language, theme color.
- [ ] Parent gate (simple math/long-press) so kids can't edit profiles.

### Onboarding quiz (kid-friendly, preference-based, no PII)
- [ ] Author the **full first-run quiz**. Draft set:
  1. Favorite kind of creature? (dragon / puppy / robot / something else)
  2. Real-world adventures or magical ones?
  3. Funny stories or exciting ones?
  4. **Stories you already love?** (free text or pick — favorite books/films/shows)
  5. **A favorite character?** (free text — e.g. a hero they adore)
  6. Favorite place? (space / ocean / forest / castle / city)
  7. A friend who comes along? (animal sidekick / robot / fairy / none)
  8. Daytime bright stories or cozy nighttime ones?
  9. Something you love right now? (free text — seeds first interest)
  10. How long should stories be? (short / medium / long)
  11. Something a little scary you'd rather NOT hear about? (soft hint only — real bans live in Settings)
- [ ] **Parent's Brief** (optional, gated): free-text field (sentence → paragraphs) for values/tone to hone stories. Stored on `ChildProfile`. See [../docs/safety.md](../docs/safety.md).
- [ ] Quiz UI — one question per screen, big choices, progress dots; voice-read questions (reuse TTS later).
- [ ] Persist `QuizResult`; derive `seedSummary` (distill answers + brief into a premise).
- [ ] Q4/Q5 ("stories/characters they love") + Q9 → seed `Interest`s; Q10 → `detailLevel`; Q11 → soft hint (banned **themes** are set in Settings, [../docs/safety.md](../docs/safety.md)).

> **Hero choice is NOT in the quiz.** It's picked when starting each new story/series (child-as-hero / named hero / surprise) — see Phase 2 and `Series.heroMode`.

### Adaptive / evolving quiz
- [ ] Support quiz `kind`: `full` (first run), `mini` (new series — short "what kind of story this time?"), `checkin` (occasional single refining question).
- [ ] Scaffold `LearnedProfile` (see [../docs/data-model.md](../docs/data-model.md)) — updated from play (twist picks, favorites, inferred interests) so the app keeps learning the kid without re-quizzing. (Populated by the engine in Phase 2; structure + persistence here.)
- [ ] Offer a full re-quiz when the kid ages into a new band.

### Domain & tests
- [ ] `QuizResult` (+ brief) → `seedSummary` mapping is pure + unit-tested.
- [ ] Profile + `LearnedProfile` persistence round-trip tests.

## Exit criteria
- Can create multiple children, each with a quiz-derived seed, all saved locally and surviving restart.
- Banned topics + detail level captured and stored.

## Dependencies
- Phase 0 storage + models.

## Notes
- Keep quiz copy localizable (no hardcoded strings) — see [../docs/i18n.md](../docs/i18n.md).
- The seed is the *starting* premise; the story engine (Phase 2) consumes it.
