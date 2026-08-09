# Plan: competing LLMs (deferred)

A setting where several providers each draft the chapter, a master model
critiques them, picks the best and refines it — instead of one model writing
and the same model editing.

**Not built.** This is the shape it would take, written down so the thinking
isn't lost. The default stays what it is today: one model writes, the same
model does the editorial second pass.

## Why it was deferred

It is the largest outstanding item, and unlike everything else in this area it
is not a fix — the current single-model path works and produces good chapters
(see [story-quality.md](story-quality.md)). It also multiplies cost sharply, so
it wants to be a deliberate choice rather than a default.

## The cost, plainly

Today a six-chapter story is **12 provider calls** — one draft and one edit per
chapter. With three drafters plus a judge it becomes **roughly 30**, and the
judge's prompt carries three full chapters of text each time, so token cost
rises faster than call count.

That is the number to put in front of a parent before they switch it on.

## What it needs

**Multi-key storage.** `SecretStore` already holds one key per provider, so the
keys are there. What is missing is a notion of "which providers are enabled for
drafting", separate from `selectedProvider`, plus consent covering all of them
rather than one.

**A provider list, not a provider.** `aiProvider` in
[app_providers.dart](../lib/app_providers.dart) resolves to a single
`AiProvider`. An ensemble needs the set of providers that have a key *and*
consent, with the master being one of them (probably the currently selected
one, so the choice stays meaningful).

**Orchestration.** Draft in parallel — they are independent, and serial would
make bedtime wait three times over. Then one judging call. The engine's
existing guards still apply to whatever comes back: length, safety, paragraph
structure, `is_final` carried over from the winning draft.

**A critique prompt.** The hard part, and the reason this is not just plumbing.
It has to judge against the same brief the drafts were written to — age band,
read-aloud quality, bedtime arc, continuity with the story so far — and return
a *choice plus edits*, not a review. Worth reusing the structure of
`buildRefinement`, which already encodes what "good" means here.

**Failure behaviour.** If a drafter errors or rate-limits, the ensemble should
proceed with the drafts it has rather than failing the turn. If the judge
fails, fall back to any single safe draft. Bedtime must not break because one
provider is having a bad night — the same principle as `_fallback()`.

## Open questions

- Does the judge see which model wrote which draft? Hiding it avoids a bias
  toward the master's own style; showing it allows "prefer X for dialogue".
- Is the winner refined, or is the best-of-three already the refined output?
  Refining the winner is another call on top of the ~30.
- Per-child or global? A setting this expensive probably belongs in the
  parent-only area rather than per story.
- Worth measuring first: does a three-way pick actually beat one model's
  draft-then-edit often enough to justify 2.5x the cost? A blind comparison of
  a few chapters would answer that before any of this is built.

## Related

- [story-quality.md](story-quality.md) — the existing second pass and its guards
- [ai-providers.md](ai-providers.md) — provider setup, keys, consent
