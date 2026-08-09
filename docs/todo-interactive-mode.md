# TODO — Interactive Mode

The build list for **Adventure mode**: stories a child plays rather than
receives. Rationale, the FLAM comparison it came from, and the reasoning behind
each decision are in [flam-study.md](flam-study.md) — this file is the checklist.

**Status:** not started. Phase C (listening mode, resume, sleep timer) is done
and shipped; everything below is open.

---

## The shape of it, in one paragraph

A story is created as either **bedtime** (today's behaviour: linear, autoplay,
calm) or **adventure** (choices mid-story, a backpack, keepsakes). One engine,
one safety guard, one set of worlds and characters — so a child's adventure
cast turns up in that night's bedtime story. The mode is a per-story choice made
at creation, carried on `Series`, defaulting to bedtime.

---

## A — Choices inside the story

> A chapter ends on a fork; the narrator reads 2–3 options; the next chapter is
> written from the one chosen. **Off in bedtime mode.**

- [ ] `StoryMode` enum (`bedtime` / `adventure`) + `mode` on `Series`
      (`intEnum`, default `bedtime`).
- [ ] `StoryChoice {id, label, hint}` — same shape as `Twist`, so the reader UI
      and prompt plumbing are shared.
- [ ] `choices: List<StoryChoice>` on `StorySegment` and `Beat`.
- [ ] `StoryIntent.choice`; reuse `StoryRequest.chosenTwist` for the steer.
- [ ] `StoryRequest.wantsChoices` =
      `series.mode == adventure && !mustConclude && chapterNumber.isOdd`.
- [ ] Drift: `choices` TEXT on `beats` + `mode` on `series`, one migration for
      both. JSON-in-a-text-column with tolerant decode, per `CastChanges`.
- [ ] `PromptBuilder._writeChoiceRequest` + a `StoryIntent.choice` line in
      `_intentLine`.
- [ ] `choices` in `storySegmentFields`, `jsonStorySchema`, and the Gemini
      schema dialect. Max 3, labels ≤ 8 words, `id` generated app-side.
- [ ] `SafetyGuard` rates the choice labels along with the prose.
- [ ] Reader: `_ChoiceCards` in place of the "Next chapter" button.
- [ ] Listening mode wakes the screen at a fork — the one moment it should.
- [ ] `_autoNext` must not advance past an unanswered fork.
- [ ] Creator: "a story to fall asleep to" / "a story to play", bedtime
      preselected.

**Two things that decide whether this is any good**

- The next chapter must **show the consequence immediately**. The standard
  failure is a chapter that nods at the choice in one line and then goes where
  it was always going.
- **Never pre-generate the unchosen branches.** It multiplies quota for output
  that is thrown away, and the Gemini per-day cap has bitten this project
  before. Repoint the existing `preload` to warm the *audio* of the chapter just
  written, while the child reads the cards.

**Tests:** a 3-choice segment round-trips through every provider codec;
`wantsChoices` false on the last chapter and in bedtime mode; no auto-advance
past a fork; the guard sees the labels.

**~2–3 days**, mostly prompt tuning.

---

## B — The backpack and the character sheet

> Objects picked up in one chapter matter three chapters later; a finished story
> leaves a keepsake.

- [ ] `StoryItem {name, description, foundInChapter, used}`.
- [ ] `StoryState {seriesId, backpack, keepsakes, traits}`.
- [ ] Drift: `story_states` table keyed by `seriesId`, JSON columns, created
      empty on upgrade.
- [ ] `StoryRequest.state` + a short prompt block listing backpack and
      keepsakes.
- [ ] Structured output: `items_gained` (max 1), `items_used`,
      `keepsake_earned` (final chapter only).
- [ ] Apply to `StoryState` **after** the safety guard passes, with the beat —
      a rejected chapter must not leave a phantom item.
- [ ] Character traits (`brave`, `curious`, `grumpy`…) appended to a
      character's prompt line — the "customise the hero" half.
- [ ] UI: backpack strip under the chapter list, items greyed once used; a
      keepsake shelf on the child's home screen.

**Rules**

- The prompt must say **do not force an item's use**, or models use everything
  in the next chapter and the backpack empties as fast as it fills.
- **No life bar.** Jeopardy has no place in something a child uses alone at
  night. Feats and keepsakes give progression without threat.
- **No engagement mechanics** — no streaks, daily rewards, "come back
  tomorrow", scarcity, or notifications about unclaimed items. Kids Category
  constraint *and* the right call for bedtime. See [CLAUDE.md](../CLAUDE.md).
- Nothing is ever lost from the backpack. Items get used, not taken.

**Tests:** an item gained in ch2 appears in ch4's prompt; a used item isn't
re-offered; a safety-failed chapter leaves state untouched; keepsakes aggregate
across worlds for one child.

**~3–4 days.**

---

## D — Voices from home

> Grandma is the voice of the Owl, in every story, in every world.

- [ ] `VoiceRecorder` adapter behind an interface, with a fake for tests.
- [ ] `StoryCharacter.voiceClipKey`.
- [ ] Record a character greeting, or a whole chapter, from the character
      editor (parent mode).
- [ ] Store under a `home/<characterId>` voice signature so `.sleepy`,
      audiobook, and Lunii export pick it up **unchanged** — they all resolve
      through `chapterAudioKeys` now.
- [ ] iOS `NSMicrophoneUsageDescription`.
- [ ] Delete recordings with the character; add a line to
      [safety.md](safety.md) — this is personal data about a third party.

**Not voice cloning.** Record and play back. Synthesising a real person's voice
from a sample is a different product with different consent and review problems.

**~2 days** plus per-platform permission work.

---

## E — Growing up with the child

> Today a child ages out of us at about seven.

- [ ] Per-`AgeRating` prompt guidance: for `big`/`older`, longer chapters, real
      (non-threatening) stakes, a subplot, dialogue carrying the scene, and far
      less narrating of feelings.
- [ ] An older-band theme group — heist, survival, sci-fi mystery, sports,
      friendship drama, myth retellings — shown only once the child's band
      reaches it.
- [ ] Chapter length by band as well as `DetailLevel`.

**The safety floor does not move.** `SafetyGuard` and banned themes stay exactly
as strict; only sentence craft and stakes change. Bedtime mode stays gentle at
every age.

**~1–2 days.** Cheapest phase, and the one that most extends how long each child
stays with the app.

---

## Order

**A → B → E → D.** A is the feature the whole comparison is about; B is what
makes A's choices matter a week later; E and D are independent and can slot in
whenever.

## Still to decide

1. Choice input: tap only, or the microphone too? STT is in the architecture
   but not in the nightly flow.
2. Keepsakes per child or per world? *(Recommendation: per child — it's their
   shelf of souvenirs.)*
3. A separate chapter cap for adventures? `maxChapters = 6` is tuned for
   bedtime; an afternoon adventure might want 10–12.
