# Phase 1 — Profiles & Quiz

**Goal:** Create per-child accounts and run the 10-question onboarding quiz that produces a story **seed**. All persisted locally.

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
