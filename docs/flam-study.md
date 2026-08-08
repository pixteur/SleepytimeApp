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
| Resume where you left off | **Done** (Phase C) — reading position on `Series`, "Continue — chapter 4" |
| Passive/screen-free listening | **Done** (Phase C) — listening mode + sleep timer |
| Own-voice recording | Not started — Phase D |
| Play away from the app | Done — `.sleepy`, audiobook export, Lunii pack export |
| Age band 7–11 | Weak — themes and `AgeRating` skew younger. Phase E |

---

# 4. Build spec

Phases ship standalone. **Phase C is done** — see
[story_view_screen.dart](../lib/ui/story/story_view_screen.dart),
[sleep_timer.dart](../lib/ui/story/sleep_timer.dart), and schema v6. The rest
are specified below in build order.

---

## Phase A — Choices inside the story

The core of Adventure mode: the child stops being an audience.

### What the child experiences

A chapter ends on a fork. The narrator reads it — *"Leo hears humming under the
floor. Does he lift the loose board, or wait for morning?"* — and the reader
shows two or three cards. Tap one; the next chapter is written from that
choice. There is always an implicit third option: the free-text/microphone box
that already exists on the creator screen, moved into the reader.

In **bedtime mode this is off**. A story that asks a question every few minutes
is a story that keeps a child awake.

### Domain

```dart
// lib/domain/models/story_choice.dart — same shape as Twist, deliberately:
// the reader UI, the prompt plumbing, and the LearnedProfile tagging are all
// shared with TwistDeck.
class StoryChoice {
  final String id;     // stable within the chapter, e.g. "lift_board"
  final String label;  // read aloud + shown: <= 8 words
  final String hint;   // steer text fed back into the next prompt
}
```

- `StorySegment` and `Beat` gain `choices: List<StoryChoice>` (empty = no fork).
- `Beat` already stores `chosenTwist`; the chosen choice's `hint` goes there, so
  the archive shows *what the child decided* with no new column.
- `StoryIntent` gains `choice`. `StoryRequest.chosenTwist` already carries the
  steer, so `StoryRequest` needs only one new field: `bool wantsChoices`.

### Persistence

Schema v6 → v7: one `TEXT` column on `beats`, `choices`, holding the JSON list.
Follow the `CastChanges.encode()/decode()` pattern — JSON in a text column,
tolerant decode that returns empty on garbage, so a partially-written row can
never crash the bookshelf.

### Prompt

`PromptBuilder` gains a `_writeChoiceRequest` alongside `_writeCastChanges`:

```
End this chapter at a genuine fork and offer 2-3 ways forward.
Each option must be something the characters could really do next, must be
distinct from the others, and must be safe and gentle. No option may be
frightening, sad, or a punishment; there is no wrong choice and no losing.
Do not name the options in the story text — just end at the moment of
deciding.
```

And in `_intentLine`:

```dart
StoryIntent.choice when twist != null =>
  'The child chose: «$twist». Open this chapter by following through on '
      'that decision, showing its consequence straight away.',
```

The last clause matters: the commonest failure of generated branching is a
chapter that acknowledges the choice in one sentence and then goes where it was
always going. The child must *see* their decision change something.

### Structured output

Add `choices` to `storySegmentFields` and `jsonStorySchema` in
[story_segment_codec.dart](../lib/adapters/ai/story_segment_codec.dart), and to
the Gemini dialect in `gemini_provider.dart`:

```json
"choices": {
  "type": "array",
  "maxItems": 3,
  "items": {
    "type": "object",
    "properties": {
      "label": {"type": "string"},
      "hint":  {"type": "string"}
    },
    "required": ["label", "hint"],
    "additionalProperties": false
  }
}
```

`choices` stays in `required` (providers with strict schemas demand every
declared property) with an empty array when no fork is wanted. `id` is
generated app-side from the label — one less thing for the model to get wrong.

### Safety

Choices go through `SafetyGuard` **as part of the segment**, not separately —
the guard already sees `storyText`; extend it to concatenate choice labels
before rating so a scary option can't slip past by living outside the prose. If
the guard rejects, the whole chapter is regenerated, as today.

### UI

- `_ReadingText` footer swaps the "Next chapter" button for a `_ChoiceCards`
  row when `beat.choices` is non-empty.
- In listening mode, the choice labels are read aloud and the screen wakes to
  show the cards — this is exactly FLAM's "screen lights up only at interaction
  points", and it is the one moment listening mode should brighten.
- Auto-advance must **not** fire past a fork: `_autoNext` returns early when
  `widget.beat.choices.isNotEmpty` and nothing is chosen yet.

### Pacing rule

At most one fork every other chapter, and **never on the last chapter** — an
ending should not be a decision. `StoryRequest.wantsChoices` computes as:

```dart
adventureMode && !mustConclude && chapterNumber.isOdd
```

A 6-chapter story then has 2–3 decisions: a story, not a quiz.

### Cost

No increase. We generate only the chosen branch. Pre-generating the other
options would double or triple quota use for output that is thrown away — and
we have already been bitten by the Gemini per-day cap. **Do not pre-generate.**
Latency does move into the middle of the session, so the existing `preload`
warm-up should be repointed: warm the *audio* of the chapter we just wrote
while the child is reading the choice cards.

### Tests

- A segment with 3 choices round-trips through each provider's codec.
- `wantsChoices` is false on the concluding chapter and in bedtime mode.
- `_autoNext` does not advance past an unanswered fork.
- Safety guard rates the choice labels, not just the prose.

**Estimate:** 2–3 days. The plumbing is small; the prompt tuning is most of it.

---

## Phase B — The backpack and the character sheet

What makes the choices in Phase A feel like they mattered a week later.

### What the child experiences

A story hands them something — a glass feather, a whistle, a map with a corner
torn off. It goes in the backpack, visible as a row of items under the chapter
list. Three chapters later the whistle is the way past a sleeping heron. At the
end of a story they keep a **keepsake**: "Brave in the Dark", "Friend of the
River". The shelf of keepsakes is theirs, across every world.

### Domain

```dart
// lib/domain/models/story_state.dart
class StoryItem {
  final String name;         // "a glass feather"
  final String description;  // one line, kid-facing
  final int foundInChapter;
  final bool used;
}

class StoryState {
  final String seriesId;
  final List<StoryItem> backpack;
  final List<String> keepsakes;
  final Map<String, String> traits; // character name → chosen trait
}
```

`traits` is the character-sheet half: when a world character is created the
grown-up (or the child, in Adventure mode) can pick a trait — *brave, curious,
grumpy, kind* — which is appended to that character's prompt line. Cheap, and it
gives the "customise the hero" feeling FLAM sells hard.

### Persistence

Schema v7 → v8: a `story_states` table keyed by `seriesId`, with `backpack` and
`keepsakes` as JSON text columns (same tolerant-decode pattern as
`CastChanges`). Keepsakes are read per-child by joining through `series`, so a
child's whole collection is one query. `onUpgrade` creates the table empty —
existing stories simply have nothing in the backpack.

### Prompt

`StoryRequest` gains `state`. `PromptBuilder` writes a short block, placed with
the cast so it reads as part of the world:

```
In the backpack: a glass feather (found in chapter 2), Leo's spare bolt.
Earned so far: Brave in the Dark.

An item may be used when it genuinely fits — do not force it. If an item is
used, say so plainly in the story. You may hand over at most one new item per
chapter, and only when the moment earns it.
```

The "do not force it" clause is load-bearing. Without it, models use every item
in the next chapter and the backpack empties as fast as it fills.

### Structured output

Three optional fields: `items_gained` (array of `{name, description}`, max 1),
`items_used` (array of names), `keepsake_earned` (string, only on a final
chapter). `StoryEngine.takeTurn` applies them to `StoryState` **after** the
safety guard passes, in the same transaction as the beat — a rejected chapter
must not leave a phantom item behind.

### UI

- A backpack strip under the chapter list: item chips, greyed once used.
- Tapping an item shows its one-line description and where it was found.
- A keepsake shelf on the child's home screen.
- Nothing is ever *lost* from the backpack. Items get used, not taken.

### Deliberate omission: no life bar

FLAM's life bar works because FLAM is a game a child plays while awake and
alert. Ours would introduce failure and jeopardy into a product used alone,
often at night, often by a younger sibling than the one it was set up for.
Feats and keepsakes give the same sense of progression with none of the threat.

### Kids Category constraint

Per [CLAUDE.md](../CLAUDE.md), if we ship in Apple's Kids Category, collectibles
must not become engagement mechanics. **No streaks, no daily-login rewards, no
"come back tomorrow to unlock", no scarcity, no notifications about unclaimed
items.** A keepsake is a souvenir of a story the child heard. That is also
simply the right call for a bedtime product, App Review or not.

### Tests

- An item gained in chapter 2 appears in chapter 4's prompt.
- A used item is marked used and is not re-offered.
- A rejected (safety-failed) chapter leaves `StoryState` untouched.
- Keepsakes aggregate across worlds for one child.

**Estimate:** 3–4 days, most of it the schema + UI.

---

## Phase D — Voices from home

FLAM's Studio app lets a parent upload unlimited audio files. Our version should
be warmer and much simpler: **record a person, not a file.**

### What the child experiences

Grandma is the voice of the Owl. Every time the Owl speaks — in any story, in
any world — it's her. Or a parent narrates a whole chapter, and that chapter
plays back in their voice forever.

### How it works

Two scopes, one mechanism:

1. **A character's greeting** — a short clip attached to a `StoryCharacter`,
   played when that character is introduced in a chapter.
2. **A whole chapter** — a parent reads the chapter text aloud; the recording
   replaces synthesis for that chapter.

Recordings are written into the existing audio cache under a voice signature of
`home/<characterId>` or `home/<childId>`. That single decision means
`.sleepy` export, audiobook export, and the Lunii pack **all pick them up with
no changes** — they resolve audio through `audioCacheKey(voiceSig|lang|text)`
exactly as they do for cloud voices.

### Domain / adapters

- A new `VoiceRecorder` adapter behind an interface (a `record` package
  implementation on desktop/mobile; a fake in tests), matching how
  `TtsSynthesizer` is already abstracted.
- `StoryCharacter` gains `voiceClipKey: String?`.
- Recording UI lives in the world's character editor, behind parent mode.

### Constraints

- **Explicitly not voice cloning.** Synthesising a real person's voice from a
  sample is a different product with different consent, safety, and App Review
  problems. Record and play back, nothing more.
- iOS needs `NSMicrophoneUsageDescription` — already on the port checklist in
  [CLAUDE.md](../CLAUDE.md).
- Recordings are personal data about a third party (a grandparent). They stay
  on-device, are never sent to a provider, and must be deleted with the
  character. Add a line to [safety.md](safety.md) when this ships.

**Estimate:** 2 days plus platform permission work per OS.

---

## Phase E — Growing up with the child

FLAM starts where *Ma Fabrique* stops. Our themes, vocabulary, and chapter
length skew younger than 7–11, so a child ages out of us.

### What changes

- **Prompt guidance per `AgeRating` band.** Today the rating is mostly a
  ceiling for the safety guard. For `big` and `older` it should also shape the
  writing: longer chapters, real (non-threatening) stakes, a subplot, dialogue
  that carries the scene, and much less narrating of feelings — an 11-year-old
  hears "Bob felt sad" as writing for babies.
- **A theme set for the older band** — heist, survival, sci-fi mystery, sports,
  friendship drama, myth retellings — surfaced in `themeGroups` only when the
  child's age band reaches it, rather than shown to a four-year-old.
- **Chapter length by band**, not only by `DetailLevel`. `long` for a 5-year-old
  and `long` for an 11-year-old should not be the same word count.
- Adventure mode is where this band actually lives. **Bedtime mode stays gentle
  at every age** — an 11-year-old still wants to fall asleep.

### The thing to be careful about

Loosening the tone for older children must not loosen the **safety floor**.
`SafetyGuard` and the banned-themes list stay exactly as strict; what changes is
sentence craft and stakes, not what is permitted. The band affects style, never
the guard.

**Estimate:** 1–2 days, mostly prompt work and one new theme group. Cheapest
phase here, and the one that most extends the product's lifespan per child.

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
- **Voice cloning.** See Phase D.

## 6. Sequencing

1. ~~**C** — listening mode, resume, sleep timer.~~ **Done.**
2. **A** — choices inside the story. The feature the comparison is about.
3. **B** — backpack and keepsakes. What makes A's choices matter.
4. **E** — growing up. Cheap, independent, and it extends every other phase.
5. **D** — voices from home. Independent; needs per-platform permission work.

A and B together are the interesting bet: **a generated interactive adventure
has no branch budget**. FLAM can offer a child three doors. We can offer them a
door they invent themselves — and then remember what they found behind it, in
this story and the next one.

## 7. Open questions

1. Does Adventure mode live in the same app, or is it a mode switch in the
   parent area? *(Recommendation: a per-story choice at creation — "a story to
   fall asleep to" vs "a story to play". It then rides on `Series`, so the
   engine reads one flag and the shelf can show both kinds side by side.)*
2. Is the choice input tap-only, or is the microphone in the loop? We have STT
   in the architecture but not in the nightly flow.
3. Do keepsakes belong to the child (across all worlds) or to the world?
   *(Recommendation: the child — it is their shelf of souvenirs.)*
4. Does Adventure mode need its own chapter cap? `maxChapters = 6` is tuned for
   bedtime; an afternoon adventure might want 10–12.

## Sources

- [FLAM product page (Lunii)](https://lunii.com/fr-fr/products/flam-coque-verte-incluse?variant=fr_FR)
- [FLAM announcement, Lunii blog](https://blog.lunii.com/2023/10/18/flam-le-baladeur-audio-interactif-par-lunii/)
- [FLAM review — La P'tite Famille Baroudeuse](https://laptitefamillebaroudeuse.fr/baladeur-flam-lunii-test-complet-avis)
- [FLAM review — Église Roanne](https://eglise-roanne.fr/lunii-flam-baladeur-dhistoires-audio-interactives-avis/)
- [Ma Fabrique à Histoires (the 3–8 product)](https://lunii.com/en-us/products/ma-fabrique-a-histoires-bilingue)
