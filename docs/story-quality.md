# Story quality: chapter titles and the editorial second pass

Two things happen between the model finishing a chapter and a child hearing it.

## Chapter titles

Each generation returns `chapter_title` alongside the existing `story_title` —
a 2–5 word name for *this* chapter only, no "Chapter N" prefix, no ending
punctuation, concrete rather than abstract ("The Lost Mitten", not "A New
Beginning"), and never a spoiler.

It lands on `Beat.title` and shows in the reading header as
`Chapter 3 · The Lost Mitten`, scrolling sideways via
[marquee_text.dart](../lib/ui/common/marquee_text.dart) when it is too long to
fit. The field is allowed to be blank — fallback chapters have no title, and
neither does anything written before schema v6 — so the header falls back to the
bare chapter number.

## The second pass

Every generated chapter is handed straight back to the same model as an editor
before it is saved, shown, or narrated. The child never sees the draft. From the
app's point of view a chapter simply takes a little longer to appear.

`PromptBuilder.buildRefinement` writes the brief. Its shape is driven by two
things that go wrong otherwise.

**A model asked to "improve" prose rewrites it.** It will happily invent a new
character, relocate a scene, or resolve a story that was meant to continue — and
the summary, the open threads and the *next* chapter have all already been
planned around this draft's ending. So the prompt pins the plot ("no new named
characters, no new places, no new or removed events; same opening situation,
same closing situation"), pins `is_final`, and pins the length to ±10% of the
draft's actual word count, which is measured and injected.

**Prose edited for the page trips a synthetic voice.** This text is spoken, never
read silently, so the brief treats read-aloud quality as a first-class goal:
one comfortable breath per sentence, punctuation where the voice should breathe,
nothing over ~25 words, no tongue-twisters or hissing clusters, numbers and
abbreviations spelled out, and **no em dashes or semicolons** — a speech engine
either stops hard on them or drops them entirely.

The rest of the brief covers errors, continuity (including keeping each
character's species, role and pronouns exactly as the cast list gives them),
concrete sensory detail over abstraction, deliberate repetition kept as craft
while accidental repetition goes, and a bedtime arc that falls toward a calm
close. The selected age band is injected verbatim from
[age_policy.dart](../lib/domain/age_policy.dart), so a pass for a 3-year-old and
a pass for a 9-year-old are given different targets.

It ends by saying a light pass is a success — otherwise a model rewrites to show
effort and flattens a voice that was already working.

## Nothing about the polish is taken on trust

`StoryEngine._refine` treats the edit as untrusted input, because a model asked
to polish can return a summary, a critique, or an empty string, and any of those
would silently replace a good chapter with rubbish that a child then hears.

- **Length is measured**, not assumed: outside 0.6×–1.5× of the draft, the edit
  is discarded. That band is deliberately wider than the ±10% the prompt asks
  for — it exists to catch a summary or a truncation, not to police the brief.
- **The safety guard runs again** on the refined text, at the same band.
- **`is_final` and `rating` are carried over from the draft**, never accepted
  from the edit.
- **Empty fields fall back** to the draft's, so a lazy edit cannot blank a
  summary or a title.
- **Any exception keeps the draft.** A failed polish must not cost a child their
  bedtime story.
- **Fallback chapters are never refined** — there is no point polishing the
  safety net, and it would spend a call on a night that is already going wrong.

Turn the whole pass off with `StoryEngine(refinePass: false)`; the tests use
this when they need to assert on the generation prompt.

## Cost

One extra API call per chapter, roughly doubling per-chapter cost and latency.
A six-chapter story goes from six calls to twelve.
