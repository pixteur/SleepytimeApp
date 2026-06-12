# Phase 1 — Profiles & Quiz

**Goal:** Create per-child accounts and run the 10-question onboarding quiz that produces a story **seed**. All persisted locally.

## Tasks

### Child profiles
- [ ] Implement `StorageRepo` (local DB) for `ChildProfile` CRUD.
- [ ] `ProfileService` (domain) — create/list/update/delete, set active child.
- [ ] **Profile select** screen — avatar cards, "add child".
- [ ] **Create/edit profile** (gated for parents) — nickname, avatar, age, language, theme color.
- [ ] Parent gate (simple math/long-press) so kids can't edit profiles.

### Onboarding quiz
- [ ] Author the **10 questions** (kid-friendly, preference-based, no PII). Draft set:
  1. Favorite kind of creature? (dragon / puppy / robot / something else)
  2. Real-world adventures or magical ones?
  3. Funny stories or exciting ones?
  4. Pick a hero name / what should the hero be called?
  5. Favorite place? (space / ocean / forest / castle / city)
  6. A friend who comes along? (animal sidekick / robot / fairy / none)
  7. Daytime bright stories or cozy nighttime ones?
  8. Something you love right now? (free text — seeds first interest)
  9. How long should stories be? (short / medium / long)
  10. Something that's a little scary you'd rather NOT hear about? (feeds banned topics)
- [ ] Quiz UI — one question per screen, big choices, progress dots; voice-read questions (reuse TTS later).
- [ ] Persist `QuizResult`; derive `seedSummary` (distill answers into a premise).
- [ ] Q8 → seed an initial `Interest`; Q10 → seed banned topics; Q9 → `detailLevel`.
- [ ] Allow re-taking the quiz as the kid grows (`version`).

### Domain & tests
- [ ] `QuizResult` → `seedSummary` mapping is pure + unit-tested.
- [ ] Profile persistence round-trip tests.

## Exit criteria
- Can create multiple children, each with a quiz-derived seed, all saved locally and surviving restart.
- Banned topics + detail level captured and stored.

## Dependencies
- Phase 0 storage + models.

## Notes
- Keep quiz copy localizable (no hardcoded strings) — see [../docs/i18n.md](../docs/i18n.md).
- The seed is the *starting* premise; the story engine (Phase 2) consumes it.
