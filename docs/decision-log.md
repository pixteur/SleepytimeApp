# Decision Log / Project Memory

> A running record of decisions, why we made them, and open questions. Newest at top. Update this whenever a meaningful choice is made — it's the project's memory.

---

## 2026-06-12 — Project kickoff & foundational decisions

**Context:** Starting SleepytimeApp — a kids' nighttime storytelling app. PC-first, port to Mac/iOS. AI invents each night's chapter; voice reads it aloud.

**Decisions:**
1. **UI framework → Flutter.** One codebase Windows → macOS → iOS, great touch + theming. (Flutter/Dart not yet installed on this machine — Phase 0 task.)
2. **AI backend → multi-provider, BYO-key for dev, hosted-ready.** Claude/OpenAI/Gemini behind an `AiProvider` interface; Claude is the default for safety adherence. Architecture must allow a drop-in `HostedProvider` so this can become a billed product without touching the core. (User: *"setup for 2 and 3 — 2 for initial dev but the backend is built to switch to a hosted backend to make it a product."*)
3. **Data → local-only on device.** Privacy/COPPA-first; optional cloud sync deferred to Phase 6.
4. **Kickoff → repo + docs + phased build plan**, **plus** a designed-in **voice story reader**: male/female, multi-language, expressive character voices kids like. (User explicitly added this to the kickoff.)

**Architecture stance:** pure-Dart domain layer (story engine, prompt builder, safety guard, beat store) with swappable adapters (AI, TTS, STT, storage, secrets). Keeps logic testable and porting cheap. See [architecture.md](architecture.md).

**Safety stance:** four-layer defense (age policy injection → input guarding → output guardrail → continuity guard) with a never-break-bedtime fallback. See [safety.md](safety.md). This is the project's highest priority.

**Open questions to revisit:**
- Local DB: **Drift** (leaning) vs Isar — decide in Phase 2.
- Context window strategy (full recent beats + summarized history + story-bible) — tune against real token costs in Phase 2.
- Streaming generation + sentence-boundary TTS — nice-to-have, Phase 2/3.
- Character voice casting depth (pitch presets vs multi-voice cloud) — Phase 3.

**Repo:** `git init` on `main`, `core.autocrlf=true` (Windows). `.gitignore` blocks secrets, Flutter build artifacts, local data.

---

## Template for new entries

```
## YYYY-MM-DD — <short title>
**Context:** …
**Decision:** …
**Why:** …
**Alternatives considered:** …
**Affects:** <docs/files>
**Open questions:** …
```
