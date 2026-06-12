# Data Model

All data is **local-only** at launch, behind a `StorageRepo` interface so the same shape can later sync to a hosted backend. Leaning **Drift** (SQLite) for queryable beat history + clean migrations; final call in Phase 2.

## Entities

### ChildProfile
The account for one kid.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `displayName` | string | Kid-chosen nickname; avoid real full names (privacy) |
| `avatar` | enum/asset | Picked, not uploaded (no camera/PII) |
| `birthYear` or `age` | int | Drives the **age band** (see [safety.md](safety.md)) |
| `language` | locale | `en`, `fr`, `es`, `ja`, … (see [i18n.md](i18n.md)) |
| `detailLevel` | enum | `short` / `medium` / `long` |
| `intensity` | int (band-relative) | Cozier ↔ more adventurous |
| `preferredVoice` | voiceId | Male/female/character — see [voice-tts.md](voice-tts.md) |
| `themeColor` | color | UI personalization |
| `createdAt` / `updatedAt` | datetime | |

### QuizResult
Answers from the 10-question onboarding; becomes the story **seed**.

| Field | Type | Notes |
|-------|------|-------|
| `childId` | fk | |
| `answers` | map<qId, value> | Favorite animal, real/fantasy, funny vs adventurous, hero name, etc. |
| `seedSummary` | string | Distilled premise the engine starts from |
| `version` | int | Quiz can be re-taken as the kid grows |

### Interest
A "new interest" nudge.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `childId` | fk | |
| `label` | string | e.g. "Jupiter", "fractals", "dinosaurs" |
| `weight` | int | How strongly to nudge (parent-tunable) |
| `active` | bool | Toggle without deleting |
| `addedAt` | datetime | Newer interests can nudge a bit harder |

### Beat  ← the unit of story memory
One saved chapter, **structured** so the saga stays coherent for weeks without resending everything.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `childId` | fk | |
| `seq` | int | Order in the saga |
| `intent` | enum | `dice` / `option` / `continue` / `request` |
| `chosenTwist` | string? | Which option/dice/typed request drove it |
| `text` | string | The full chapter as shown/read |
| `summary` | string | Short recap for context windows |
| `characters` | list | Names + one-line descriptions (recurring cast) |
| `setting` | string | Where we are now |
| `openThreads` | list | Unresolved hooks to (maybe) pay off later |
| `rating` | enum | Self-reported + guard-validated (see safety) |
| `sensitiveFlags` | list | Any elements the guard noted |
| `language` | locale | |
| `provider` / `model` | string | Which AI produced it (debug/repro) |
| `createdAt` | datetime | |

### Settings (per child + app-global)
Theme, default language, intensity, banned topics list, active AI provider + which voice provider, detail level defaults.

### SecretRef (NOT in the DB)
API keys live in **OS secure storage** via `SecretStore` (Windows Credential Manager / macOS & iOS Keychain). Only a reference/flag ("Claude key present") is in app state. Never persisted to the DB, never logged, never committed.

## Context window strategy ("continue where we left off")

Sending the entire saga every night gets expensive and slow. Strategy:

1. Always include the **seed summary** + the child's profile/interests.
2. Include the **last K full beats** (e.g. 2–3) verbatim for immediate continuity.
3. Include **summaries only** of older beats + a deduped list of recurring `characters` and unresolved `openThreads`.
4. Optionally keep a single rolling **"story bible"** summary the engine updates each turn (cheaper than re-summarizing history every time).

`BeatStore.recentContext(child)` encapsulates this so the engine and tests don't care how it's assembled. Tunable as we learn real token costs (revisit in Phase 2).

## Migrations & versioning

- Schema versioned from day one (Drift migrations). Beats are long-lived user data — never destructively migrate without a tested upgrade path.
- `QuizResult.version` and prompt-template versions are stored on beats so we can reason about "which rules produced this".

## Future: cloud sync (Phase 6)

Same entities, same `StorageRepo` interface, with a sync adapter (last-write-wins or per-field merge) + encryption in transit/at rest. Requires the consent/compliance work in [safety.md](safety.md) first.
