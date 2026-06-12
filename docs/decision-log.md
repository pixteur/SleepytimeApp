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

## 2026-06-12 — Feature & design refinements (review round)

**Context:** Reviewing the draft docs/quiz; user added several features and resolved parked decisions.

**Decisions:**
1. **Local DB → Drift (SQLite).** Series→beats, branching, and the archive are relational and need real queries + safe migrations. (Was leaning Drift; now locked.)
2. **Second-model safety reviewer → ON by default**, toggle in Settings (~2× cost; parent can disable).
3. **Hero choice → at new-series start**, not in the quiz. `Series.heroMode` = child-as-hero / named / surprise.
4. **Streaming generation → yes.** Stream story text; sentence-boundary hand-off to TTS in Phase 3.
5. **Story archive** — per-series list of past episodes (each with a `summary`), replayable via the voice reader (Phase 3).
6. **Story series + branching** — new `Series` entity; a child has multiple parallel storylines, can branch a new one (optionally forked from a beat via `branchedFromBeatId`). **Beats now belong to a series.** Drives a **story library** screen.
7. **Multi-user/multi-kid** — multi-kid already supported (many `ChildProfile`s/device). Multi-*parent* accounts deferred to hosted Phase 6.
8. **Adaptive/evolving quiz → yes.** Quiz `kind` = full / mini (per new series) / checkin (single refining Q). New `LearnedProfile` entity grows from play (twist picks, favorites, inferred interests) and feeds `PromptBuilder`; full re-quiz offered when the kid changes age band.

**Quiz changes:** added "stories/characters you already love" questions; banned **themes** moved to Settings (quiz only gives a soft hint).

**Parent's Brief:** new optional free-text field (on `ChildProfile`, optional per `Series`) for **values and tone** — the positive companion to the ban list. Injected into every prompt.

**Banned themes:** defaults pre-set per family — sex, drugs, alcohol, flirting, religion, evolution, birthdays, Christmas — plus a grouped menu of optional toggles (violence, death/grief, horror, occult/supernatural, other holidays, romance, real-world danger, crude/unkind, politics/gambling/etc.). Banned themes are a floor on top of the age band; stricter wins. See [safety.md](safety.md).

**Affects:** README, data-model.md (new Series + LearnedProfile entities, parentBrief, beat.seriesId), safety.md (banned themes menu, reviewer default, parent brief), architecture.md (SeriesService, LearnedProfile), ui-ux.md (library + archive screens), build-plan phases 1–3.

**Open questions:** twist deck = fixed categories with AI-flavored text (leaning); exact mini-quiz question set; confirm Drift schema v1 fields in Phase 2.

---

## 2026-06-12 — Series themes (chooser) + bilingual as a modifier

**Context:** Added a theme chooser when starting a new series — the series' overall *flavor*, distinct from the per-night twist deck. Then expanded the theme set and reclassified bilingual.

**Decisions:**
- **Full theme set (~16 + custom):** `adventure` · `technical` · `nature` · `documentary` · `learning` · `cozy` · `feelings` · `mystery` · `silly` · `fairytale` · `history` · `aroundTheWorld` · `superhero` · `mindfulness` · `sliceOfLife` · `surprise` · `custom` (+ `customTheme` free-text). Picked at new-series setup (theme → hero → mini-quiz). Chooser is **grouped** (Exciting / Calm & Bedtime / Discover & Learn / Imagine & Giggle / Surprise · Custom) so ~16 options aren't overwhelming.
- **Bilingual is a MODIFIER, not a theme** (user call). `bilingualEnabled` + `secondaryLanguage` + `bilingualBlend` (`sprinkle`/`phrases`/`alternating`) can layer onto *any* theme. Model emits **language-tagged spans**; voice reader switches language per span (cloud-TTS fallback where device lacks the 2nd voice).
- **Settings vs interests vs themes:** specific topics (pirates, space, dinosaurs) stay as **Interests/seed**, NOT themes, to keep the theme list broad (~16) and avoid sprawl.

**Why:** themes give a strong, predictable lever on tone/content; decoupling bilingual lets *every* flavor double as language practice. Theme sets series flavor; twist deck drives each episode within it.

**Affects:** README, data-model.md (Series.theme full enum + bilingual fields decoupled), ui-ux.md (grouped chooser + bilingual toggle), i18n.md + voice-tts.md (bilingual mode), build-plan phases 2–3. PromptBuilder golden-tested per theme + age band.

**Open questions:** exact prompt recipe per theme; bilingual correctness/age-appropriateness guardrails for the 2nd language; whether `bilingualBlend` auto-steps-up as the kid progresses; final emoji/icon set for theme cards.

---

## 2026-06-12 — Phase 0 complete (toolchain + skeleton + CI)

**Context:** Built the foundation so feature work can start.

**Environment / toolchain:**
- **Flutter 3.44.2 stable** installed via shallow `git clone` to `C:\src\flutter` (winget has no Flutter SDK package); added to user PATH. Dart 3.12.2.
- **No Visual Studio install needed:** the machine already had **Build Tools 2026** (and 2022) with the C++ desktop workload (MSVC `VC.Tools`, CMake, Windows 10 SDK). `flutter doctor` accepts Build Tools as a valid "Visual Studio" for Windows desktop. Android toolchain intentionally not installed (not a target).
- gh CLI 2.93.0 installed earlier, authed as `pixteur`; repo pushed.

**Scaffold decisions:**
- Project package name **`sleepytime`** (snake_case required), org **`com.pixteur`**, `--platforms windows` only for now (macOS/iOS added in Phase 5).
- State/DI: **Riverpod** wired at root (`ProviderScope`); `aiProvider` → `FakeAiProvider`, `storyEngineProvider` → `StoryEngine`.
- **Dependencies kept minimal:** only `flutter_riverpod` + `uuid` added now. Heavier deps (Drift, `flutter_secure_storage`, `flutter_tts`, `intl`/l10n, `freezed`) deferred to the phases that use them to avoid unused-package churn.
- Domain layer is pure Dart (no Flutter imports) — models + `StoryEngine`; adapters are interfaces with a `FakeAiProvider` so everything runs offline with no key.
- **CI** on GitHub Actions (ubuntu): `dart format --set-exit-if-changed` + `flutter analyze` + `flutter test`, Flutter pinned to 3.44.2.

**Verified:** `flutter analyze` clean · 5 tests pass · `flutter build windows --debug` → `sleepytime.exe` (1.2 MB).

**Affects:** new `lib/`, `test/`, `windows/`, `pubspec.yaml`, `.github/workflows/ci.yml`; build-plan README + phase-0 marked complete.

**Open questions:** revisit whether Build Tools (vs full VS) causes any issue when adding plugins with native code (none so far); confirm `freezed`/codegen approach when models gain (de)serialization in Phase 1.

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
