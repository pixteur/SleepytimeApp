# Safety & Age-Appropriateness

> This is the most important document in the project. SleepytimeApp generates content for children, on the fly, from a language model. Safety is **enforced in code**, not left to the model's goodwill.

## Threat model (what we're protecting against)

1. **Inappropriate content** — violence, fear/horror, romance/sexual themes, scary imagery, death/grief handled poorly, substances, etc., relative to the child's age.
2. **Unsafe real-world suggestions** — anything that could prompt a child to do something dangerous (fire, heights, strangers, eating things, leaving home).
3. **Prompt injection via free input** — a child (or someone) typing/speaking a request that tries to jailbreak the model.
4. **Tone drift over a long saga** — stories that slowly creep darker or more intense across many nights.
5. **PII leakage** — the child volunteering personal info that ends up persisted or (in a future hosted phase) transmitted.

## Defense in depth — five layers

### Layer 1 — Age policy (the contract)
Each child has an **age** and a derived **age band** with a concrete, written policy. Bands (tunable):

| Band | Age | Allowed | Hard limits |
|------|-----|---------|-------------|
| **Tiny** | 2–4 | Gentle, cozy, repetition, animals, simple feelings | No conflict beyond mild/solvable, no scary imagery, no peril |
| **Little** | 5–7 | Light adventure, friendship, simple problems & resolution, wonder/STEM | No real danger, no weapons, no death on-page, no romance |
| **Big** | 8–10 | Richer plots, mild suspense, mystery, mild stakes resolved kindly | No graphic violence, no horror, no romance beyond crushes, no substances |
| **Older** | 11+ | More complex themes, friendly stakes | Still no graphic/sexual/extreme content |

The policy text for the child's band is **injected verbatim into every system prompt**, plus a few universal rules (always end safe/comforting at bedtime, kindness wins, no instructions a child could dangerously imitate).

### Layer 2 — Input guarding
- Free-text / mic requests are **sanitized and wrapped** so they're treated as *story ideas*, never instructions that can override the system policy ("The child asked for a story about: «…». Honor the spirit within the safety rules above.").
- A lightweight pre-check rejects/redirects obviously out-of-bounds requests *before* spending a model call, with a kind kid-facing message ("Let's pick something cozy instead!").

### Layer 3 — Output guardrail (`SafetyGuard.review`)
Every generated segment is checked **before it's ever shown or spoken**:
- The generation prompt requires the model to **self-report a rating** + a list of any sensitive elements as structured metadata.
- `SafetyGuard` validates that rating against the child's band and scans the text against the band's banned-theme list / patterns.
- **On fail:** regenerate with tightened constraints (bounded retries, e.g. 2). If still failing, fall back to a safe pre-written "cozy filler" beat so the child is never shown raw unvetted output and the night never breaks.
- **Second-model reviewer — ON by default** (toggle in Settings): a second model pass acts as a dedicated checker ("you are a children's content safety checker…"). Higher quality at ~2× per-story cost; a parent can disable it to save tokens. Especially valuable in the hosted phase.

### Layer 4 — Continuity guard
- Beats store their rating; `BeatStore` watches the **trend** and reminds the prompt to keep things light if intensity is creeping up.
- Every bedtime story **must resolve to a calm, safe ending** — enforced as a prompt rule and checked for in the guardrail.

### Layer 5 — Saying goodbye safely
When a grown-up removes a character from a world, the character does **not** silently disappear from the stories a child already loves. The removal is queued on the world and the next story is instructed to write them out warmly and on the page — they sail away, are called home, or set off on an adventure of their own, with a proper goodbye and the door left open. `PromptBuilder` explicitly forbids illness, death, danger, punishment, an argument, or an unexplained disappearance as the reason. A queued goodbye is only cleared once a *real* generated chapter has told it, so an API fallback can't swallow it. See [ui-ux.md](ui-ux.md), [data-model.md](data-model.md).

## Parent controls

- Set/adjust child age (moves the band).
- **Cast changes** — add or remove characters in a world (parent mode only); each change is introduced or written out by the next story, never applied silently.
- **Deletions** — a world, story, chapter, or character can only be deleted through the parent gate plus a two-step confirmation naming exactly what will be lost.
- **Banned themes** list — see below (parent toggles + free additions, e.g. "no spiders").
- **Parent's Brief** — free-text (sentence → paragraphs) to express **values and tone**, not just bans (e.g. "kindness and honesty win; family matters; no scary stuff"). Injected into every prompt for that child/series. The positive-framing companion to the ban list. Stored on `ChildProfile` (and optionally per `Series`). See [data-model.md](data-model.md).
- **Intensity dial** within a band (cozier ↔ more adventurous).
- Review/clear story history; archive/branch series.
- All settings live on-device. See [data-model.md](data-model.md).

### Banned themes — defaults & menu

Set in **Settings**, enforced by injecting the active list into every prompt **and** scanning output in `SafetyGuard`. Each item is a toggle; parents can add their own free-text bans too. Lists are per child.

**Pre-enabled by default** (family-specified): sex · drugs · alcohol · flirting/romance · religion · evolution · birthdays · Christmas.

**Suggested additional toggles** (grouped — off/on per family):

| Group | Themes |
|-------|--------|
| Violence | weapons, war, fighting, graphic injury |
| Death & grief | dying, loss, funerals |
| Fear / horror | monsters, ghosts, nightmares, the dark, jump-scares |
| Supernatural / occult | witchcraft, magic spells, fortune-telling, luck/superstition, horoscopes |
| Other holidays | Halloween, Easter, Valentine's, Thanksgiving |
| Romance (beyond flirting) | dating, marriage, kissing |
| Real-world danger (imitable) | fire, strangers/kidnapping, getting lost, heights |
| Crude / unkind | toilet humor, profanity, name-calling, bullying |
| Other | politics/nationalism, gambling, smoking/vaping, materialism/greed |

> Banned themes are a **floor**, applied on top of the age-band policy — the stricter of the two always wins. The Parent's Brief expresses the *positive* side (what stories should celebrate).

## Privacy (children's data)

- **Local-only storage** at launch — no child data leaves the device.
- API keys stored in OS secure storage, never in plaintext, never committed (see `.gitignore`).
- Minimize PII: discourage collecting real names/locations; the quiz asks for *preferences*, not identity.
- **Hosted phase (future):** must add a privacy policy, data-processing terms, parental consent flow, regional compliance (COPPA in the US, GDPR-K in the EU, etc.) **before** any child data is transmitted. Flagged in [build-plan/phase-6-hosted-backend.md](../build-plan/phase-6-hosted-backend.md).

## Testing safety

- `test/domain/safety_guard_test.dart` — a corpus of adversarial inputs and synthetic over-the-line outputs that must all be caught/redirected; run in CI.
- Golden prompts: snapshot the assembled system prompt per age band so policy changes are reviewable in diffs.
- Never ship a change to `SafetyGuard` or age policy without tests.

## Reviewer note for every PR touching generation

> Does this change weaken any of the four layers, the age policy injection, or the fallback path? If unsure, treat as **yes** and require a safety review.
