# Studying Lunii FLAM — and what Sleepytime should take from it

A look at [Lunii's FLAM](https://lunii.com/fr-fr/products/flam-coque-verte-incluse)
(€99.90, French-made, ~7–11 years) and a build spec for the parts worth
adopting. FLAM is the closest thing on the market to "the next version" of what
we're making, so it's worth being precise about where it's ahead of us, where
we're ahead of it, and where copying it would actively hurt a bedtime app.

## 1. What FLAM actually is

An interactive audio-adventure player — a chunky MP3-player shape with
mechanical buttons and a yellow wheel, aimed at the age band that has outgrown
Lunii's *Ma Fabrique à Histoires* (3–8).

The mechanics are a **role-playing game played entirely by ear**:

- **Choices that steer the story** — pick a destination, change the course of
  events, open dialogue and *negotiate* with characters.
- **A backpack** — pick up objects and use them later in the adventure.
- **Character sheets** — customise the hero, choose characters' personality
  traits.
- **A life bar**, rewards unlocked through feats, and educational content
  unlocked as a prize.
- **A colour, non-touch screen** that lights up only at interaction points; a
  passive listening mode that is "sans ondes et sans écran".
- **Resume where you left off** — repeatedly called out in reviews.
- Bluetooth + 3.5mm jack, no Wi-Fi while playing.
- A **Studio companion app** to record and upload your own audio, unlimited.
- A store of original and **licensed** stories — Harry Potter, Spider-Man,
  Dungeons & Dragons, Cluedo.

## 2. The strategic read

FLAM's branches are **recorded by voice actors**. Every choice, every
negotiation, every item-use is a hand-authored, hand-recorded audio asset. That
is simultaneously its quality moat and its hard ceiling:

| | FLAM | Sleepytime |
|---|---|---|
| Branch cost | A studio session per branch | A generation call, only for the path taken |
| Breadth of choice | Fixed, small, curated | Unbounded — the child can *say* what happens |
| Story about *this* child | No | Yes — name, interests, hero mode, their world |
| Continuity across stories | Per title | Worlds, cast, story bible, episodes |
| Quality floor | Very high (pro voice + writing) | Depends on the model and the voice |
| Offline | Total | Cached audio only |
| Cost model | €99.90 + per-title purchases | BYO API key |
| IP | Licensed | Cannot compete here — and shouldn't try |

**The gap worth closing is interactivity, not content.** FLAM proves that
7–11s want to *act inside* the story, not just receive it. We can offer that
more cheaply than anyone, because we only ever generate the branch the child
actually chose — the combinatorial explosion that caps FLAM's branching costs
us nothing.

**The trap is tone.** A life bar, peril, negotiation, and unlockable rewards are
designed to *raise* arousal. Sleepytime's job is to lower it. Lifting FLAM's
loop wholesale would make a beautifully engaging product that stops working at
the one moment it's meant to work.

### The resulting design decision

Split the product in two, sharing one engine:

- **Bedtime mode** (what exists today) — linear, autoplay, calm, ends on time.
  Interactivity is limited to seeding the story before it starts.
- **Adventure mode** (new) — the FLAM loop. For the car, a rainy afternoon, a
  waiting room. Choices mid-story, a backpack, a character sheet, keepsakes.

Same worlds, same cast, same voices, same safety guard. The child's adventure
characters can show up in their bedtime stories, which is something FLAM's
catalogue model structurally cannot do.

## 3. What we already have

Worth stating plainly, because several FLAM features are close to done:

| FLAM feature | Our status |
|---|---|
| Choices that steer the story | Partial — `TwistDeck` (50 openings, 6 shown) + free-text idea, **before** the story only |
| Customise the hero | Done — `HeroMode` (the child / a named hero / surprise) |
| Character sheets | Partial — `StoryCharacter` per world, name + description, editable |
| Recurring cast, continuity | Done, and beyond FLAM — worlds, `storyBible`, `CastChanges` arrivals/departures |
| Resume where you left off | Partial — chapter list remembers position; no "resume" affordance |
| Own-voice recording | Not started |
| Passive/screen-free listening | Not started (we are a screen app) |
| Play away from the app | Done — `.sleepy`, audiobook export, Lunii pack export |
| Age band 7–11 | Weak — themes and `AgeRating` skew younger |

## 4. Build spec

Phases are ordered so each one ships standalone and is useful on its own.

---

### Phase A — Choices inside the story

**What the child sees.** At the end of a chapter (not every chapter — see
pacing), the reader offers 2–3 spoken choices: *"Does Leo follow the humming
sound, or wait for morning?"* Tapping one — or saying it — generates the next
chapter from that choice. In bedtime mode this is **off by default**.

**Domain.**

- `StorySegment` / `Beat` gain `choices: List<StoryChoice>` where
  `StoryChoice = {id, label, hint}` — the same shape as `Twist`, so the reader
  UI and the prompt plumbing are shared with `TwistDeck`.
- `StoryIntent` gains `choice`; `StoryRequest.chosenTwist` already carries the
  steer text, so the engine needs no new field.
- The model returns choices only when asked: a `wantsChoices` flag on
  `StoryRequest`, honoured in the prompt and the structured-output schema.

**Structured output.** Add `choices` to `storySegmentFields` and
`jsonStorySchema` in
[story_segment_codec.dart](../lib/adapters/ai/story_segment_codec.dart), plus
the Gemini schema dialect. Array of `{label, hint}`, max 3, each label ≤ 8
words so it can be read aloud without dragging.

**Pacing rule.** Offer a choice at most every other chapter, and never on the
last one — the ending should not be a decision. This keeps a 6-chapter story at
2–3 decisions, which is a story, not a quiz.

**Cost.** One extra generation per chapter is *not* incurred — we generate the
chosen branch only. Net API cost is unchanged. Latency, however, moves into the
middle of the listening session, so pre-generation of the two likeliest
branches is tempting: **don't**. It doubles quota use, and we have already been
bitten by the Gemini per-day cap.

---

### Phase B — The backpack and the character sheet

The RPG layer, and the piece that makes choices feel consequential.

**Domain — new `StoryState`**, one row per series:

```dart
class StoryState {
  final String seriesId;
  final List<StoryItem> backpack;   // {name, description, chapterFound}
  final List<String> keepsakes;     // rewards/feats, kid-facing
  final Map<String, String> traits; // character name → chosen trait
}
```

Drift: one new table, `schemaVersion` 5 → 6, with a `beforeOpen` migration that
creates it empty (existing stories simply have nothing in the backpack).

**Prompt.** `StoryRequest` gains `state`. Injected as a short block:

```
In the backpack: a glass feather (found in chapter 2), Leo's spare bolt.
Earned so far: Brave in the Dark.
```

with the instruction that items may be *used* and should occasionally *matter*
— an item that is never useful is a disappointment.

**Structured output.** `items_gained`, `items_used`, `keepsake_earned` — all
optional, all short strings. `StoryEngine.takeTurn` applies them to
`StoryState` after the safety guard passes.

**Deliberate omission: no life bar.** FLAM's works because FLAM is a game. Ours
would introduce failure and jeopardy into a product a child uses alone, often at
night. Feats and keepsakes give the same sense of progress without the threat.

**Kids Category note.** Per [CLAUDE.md](../CLAUDE.md), if we ship in Apple's
Kids Category, collectibles must not become engagement mechanics — no streaks,
no daily-login rewards, no "come back tomorrow to unlock". Keepsakes are
souvenirs of stories the child heard, nothing more. This is also just the right
call for a bedtime product.

---

### Phase C — Listening mode

FLAM's screen lights only at interaction points; ours blazes all night.

- A **dark listening view**: text hidden, screen near-black, one large
  play/pause target, brightness dropped. Wakes only when a choice is offered.
- **Resume** — the bookshelf's primary action becomes *Continue "Obsidian
  Stone", chapter 4* when a story is part-heard. We already persist enough to
  do this; it needs an affordance, not a data change.
- A **sleep timer** — stop after this chapter / in 20 minutes.

Cheapest phase here, and probably the highest ratio of value to effort for the
product as it stands today.

---

### Phase D — Voices from home

FLAM's Studio app lets a parent upload unlimited audio. Our version should be
warmer and much simpler: **record a person, not a file.**

- A parent records a short clip per character ("Grandma is the voice of the
  Owl") or narrates a whole chapter themselves.
- Stored in the audio cache under a `home/<characterId>` voice signature, so
  the existing cache, `.sleepy` export, and audiobook export all pick it up
  with no changes.
- Needs microphone permission strings for iOS — already on the list in
  [CLAUDE.md](../CLAUDE.md) for the Apple port.

**Explicitly not voice cloning.** Synthesising a real person's voice from a
sample is a different product with different consent, safety, and App Review
problems. Record and play back, nothing more.

---

### Phase E — Growing up with the child

FLAM starts where *Ma Fabrique* stops. Our themes, vocabulary, and chapter
length skew younger than 7–11.

- Extend `AgeRating` guidance in the prompt for the `big`/`older` bands: longer
  chapters, real stakes, subplots, less narration of feelings.
- A **teen-adjacent theme set** — heist, survival, sci-fi mystery, sports,
  friendship-drama — gated behind the existing age band rather than shown to a
  4-year-old.
- Adventure mode is where this band actually lives; bedtime mode stays gentle
  at every age.

---

## 5. Non-goals

- **Hardware.** FLAM is €99.90 of moulded plastic and a two-year warranty. We
  export to their device instead — see [lunii-export.md](lunii-export.md).
- **Licensed IP.** Not available to us, and a personalised story about the
  child's own world is the better pitch anyway.
- **A content store.** Version 1 stays BYO-key and local-only per
  [CLAUDE.md](../CLAUDE.md); a paid story service triggers In-App Purchase
  requirements.
- **A life bar / jeopardy.** See Phase B.
- **Pre-generating unchosen branches.** See Phase A.

## 6. Sequencing

Phase C first — it is small, it improves the product that exists today, and
"resume" plus a sleep timer are the two things reviewers of *every* device in
this category praise. Then A (choices), then B (backpack), which is where the
FLAM comparison is actually won. D and E are independent and can slot in
whenever.

Phases A and B together are the interesting bet: **a generated interactive
adventure has no branch budget**. FLAM can offer a child three doors. We can
offer them a door they invent themselves — and then remember what they found
behind it, in this story and the next one.

## 7. Open questions

1. Does Adventure mode live in the same app, or is it a mode switch in the
   parent area? (Recommendation: a mode toggle per *story*, chosen at creation
   — "a story to fall asleep to" vs "a story to play".)
2. Is the choice input tap-only, or do we want the microphone in the loop? We
   have STT in the architecture but not in the nightly flow.
3. Do keepsakes belong to the child (across all worlds) or to the world?
   (Recommendation: the child — it is *their* shelf of souvenirs.)

## Sources

- [FLAM product page (Lunii)](https://lunii.com/fr-fr/products/flam-coque-verte-incluse?variant=fr_FR)
- [FLAM announcement, Lunii blog](https://blog.lunii.com/2023/10/18/flam-le-baladeur-audio-interactif-par-lunii/)
- [FLAM review — La P'tite Famille Baroudeuse](https://laptitefamillebaroudeuse.fr/baladeur-flam-lunii-test-complet-avis)
- [FLAM review — Église Roanne](https://eglise-roanne.fr/lunii-flam-baladeur-dhistoires-audio-interactives-avis/)
- [Ma Fabrique à Histoires (the 3–8 product)](https://lunii.com/en-us/products/ma-fabrique-a-histoires-bilingue)
