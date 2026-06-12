# Data Model

All data is **local-only** at launch, behind a `StorageRepo` interface so the same shape can later sync to a hosted backend. **DB choice: Drift (SQLite)** — chosen because series → beats, branching, and the archive are genuinely relational and need real queries + safe migrations (see decision log 2026-06-12).

## Entity overview

```
ChildProfile 1───* Series 1───* Beat
     │  │              │  └─ branchedFromBeatId ──┐ (fork point in another series)
     │  │              └─ heroMode, parentBrief    │
     │  ├─* Interest                               │
     │  ├─1 LearnedProfile  (grows from play)      │
     │  └─* QuizResult (versioned, can re-take) ◄──┘
Settings (per child + global): banned themes, provider, voice, theme …
SecretRef → OS secure storage (never in DB)
```

## Entities

### ChildProfile
The account for one kid. Multiple kids per device (multi-kid); multiple *parent* accounts is a hosted-phase feature (Phase 6).

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `displayName` | string | Kid-chosen nickname; avoid real full names (privacy) |
| `avatar` | enum/asset | Picked, not uploaded (no camera/PII) |
| `birthYear` or `age` | int | Drives the **age band** (see [safety.md](safety.md)) |
| `language` | locale | `en`, `fr`, `es`, `ja`, … (see [i18n.md](i18n.md)) |
| `detailLevel` | enum | `short` / `medium` / `long` (default; overridable per series) |
| `intensity` | int (band-relative) | Cozier ↔ more adventurous |
| `preferredVoice` | voiceId | Male/female/character — see [voice-tts.md](voice-tts.md) |
| `themeColor` | color | UI personalization |
| `parentBrief` | string? | **Optional free-text** (sentence → paragraphs) from a parent to hone the whole child's stories: values, tone, things to emphasize. A per-series brief can override/extend it. |
| `createdAt` / `updatedAt` | datetime | |

### QuizResult
Answers from onboarding; becomes a series **seed**. **Versioned and evolvable** — a new series uses a short mini-quiz, and a full re-quiz is offered as the kid grows. See [i18n.md] for localization.

| Field | Type | Notes |
|-------|------|-------|
| `childId` | fk | |
| `kind` | enum | `full` (first run) / `mini` (new series) / `checkin` (single refining question) |
| `answers` | map<qId, value> | Preferences incl. **stories they already like** (books/films/shows/characters) |
| `seedSummary` | string | Distilled premise the engine starts from |
| `version` | int | Quiz can be re-taken / evolves over time |

### LearnedProfile  ← grows as the app gets to know the kid
A living model updated from play, so stories improve without re-quizzing. Feeds `PromptBuilder` as soft weights.

| Field | Type | Notes |
|-------|------|-------|
| `childId` | fk | |
| `twistAffinity` | map<tag,count> | Which twist cards/dice outcomes the kid tends to pick |
| `favorites` | list<beatId/seriesId> | Replayed episodes, thumbs-up → these signal what they love |
| `inferredInterests` | list | Topics the kid keeps steering toward (candidate Interests) |
| `observedTone` | summary | Funnier vs more adventurous, preferred length in practice |
| `updatedAt` | datetime | |

### Interest
A "new interest" nudge (parent-added or inferred).

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `childId` | fk | |
| `label` | string | e.g. "Jupiter", "fractals", "dinosaurs" |
| `weight` | int | How strongly to nudge (parent-tunable) |
| `active` | bool | Toggle without deleting |
| `source` | enum | `quiz` / `parent` / `inferred` |
| `addedAt` | datetime | Newer interests can nudge a bit harder |

### Series  ← a storyline; a child can have several in parallel
Enables the **story list** (pick which saga to continue) and **branching** (start a fresh series, optionally forked from a point in an existing one).

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `childId` | fk | |
| `title` | string | Kid/AI-named, e.g. "The Cloud Pirates" |
| `coverEmoji` / `coverColor` | | For the library "shelf" |
| `seedSummary` | string | Premise for this series |
| `heroMode` | enum | `childAsHero` / `namedHero` / `surprise` — **chosen when starting the series** |
| `heroName` | string? | If `namedHero` |
| `parentBrief` | string? | Optional per-series hone (extends the profile brief) |
| `storyBible` | string | Rolling summary the engine maintains for this series (cheap continuity) |
| `branchedFromBeatId` | fk? | If forked from another series' beat |
| `status` | enum | `active` / `archived` |
| `detailLevel` | enum? | Optional per-series override of the profile default |
| `createdAt` / `updatedAt` | datetime | |

### Beat  ← the unit of story memory (one episode/chapter)
Belongs to a **Series**. Structured so a saga stays coherent for weeks and so the **archive** can show a short summary per episode.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `seriesId` | fk | **Which storyline** this episode belongs to |
| `childId` | fk | Denormalized for convenience |
| `seq` | int | Order within the series |
| `intent` | enum | `dice` / `option` / `continue` / `request` |
| `chosenTwist` | string? | Which option/dice/typed request drove it |
| `text` | string | The full episode as shown/read |
| `summary` | string | **Short recap — powers context windows AND the archive list** |
| `characters` | list | Names + one-line descriptions + speaker label (for voice casting) |
| `setting` | string | Where we are now |
| `openThreads` | list | Unresolved hooks to (maybe) pay off later |
| `rating` | enum | Self-reported + guard-validated (see safety) |
| `sensitiveFlags` | list | Any elements the guard noted |
| `feedback` | enum? | Kid thumbs up/down → feeds LearnedProfile |
| `language` | locale | |
| `provider` / `model` | string | Which AI produced it (debug/repro) |
| `createdAt` | datetime | |

### Settings (per child + app-global)
Theme, default language, intensity, **banned themes list** (see [safety.md](safety.md)), active AI provider, **second-model safety reviewer toggle (on by default)**, voice provider, detail-level defaults, streaming on/off.

### SecretRef (NOT in the DB)
API keys live in **OS secure storage** via `SecretStore` (Windows Credential Manager / macOS & iOS Keychain). Only a reference/flag is in app state. Never persisted to the DB, never logged, never committed.

## Story library, archive & branching

- **Story list (library):** all of a child's `Series` shown as shelf cards (title, cover, last-played). Tap to **continue** that series.
- **Branch off:** create a new `Series` from scratch (new mini-quiz + hero choice) or **fork** from a chosen beat (`branchedFromBeatId`) to explore a "what if" without disturbing the original.
- **Archive (per series):** list its `Beat`s with each `summary`; tap any past episode to **re-read or replay via the voice reader** (Phase 3).

## Context window strategy ("continue where we left off")

Per **series**, not per child. `BeatStore.recentContext(series)` assembles:
1. Series `seedSummary` + `parentBrief`/profile brief + child profile + active interests + `LearnedProfile` weights.
2. The **last K full beats** (e.g. 2–3) verbatim for immediate continuity.
3. **Summaries only** of older beats + deduped recurring `characters` and unresolved `openThreads`.
4. The rolling **`storyBible`** the engine updates each turn (cheaper than re-summarizing history every time).

Tunable against real token costs (revisit in Phase 2).

## Migrations & versioning

- Schema versioned from day one (Drift migrations). Beats/series are long-lived user data — never destructively migrate without a tested upgrade path.
- `QuizResult.version` + prompt-template versions stored on beats so we can reason about "which rules produced this."

## Future: cloud sync (Phase 6)

Same entities, same `StorageRepo` interface, plus a sync adapter + encryption. Requires the consent/compliance work in [safety.md](safety.md) first. **Multi-parent accounts** also land here.
