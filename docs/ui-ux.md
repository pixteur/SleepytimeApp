# UI / UX

## Principles

- **Two audiences, one app.** Kids drive the story; parents own setup & safety. Keep parent controls behind a gentle gate (e.g. a "grown-ups" tap-pattern or simple math gate) so kids can't wander into settings/keys.
- **Big, calm, bedtime-friendly.** Large touch targets, soft contrast, dark-friendly palette, minimal text for pre-readers, generous spacing.
- **Touch-first from day one.** Even on Windows, design for finger-sized targets so the iOS port is layout-tuning, not redesign.
- **Personalizable.** Per-child theme color and avatar; the app should feel like *theirs*.

## Screens

| Screen | Audience | Purpose |
|--------|----------|---------|
| **Profile select** | Kid | Pick which child (avatar cards). Big, friendly. Multi-kid. |
| **Story library** | Kid | Shelf of the child's **series**; continue one, or **branch off** a new series. |
| **New-series setup** | Kid (+parent) | Pick a **theme**, then the **hero**, then a quick mini-quiz → seeds the series. |
| **Home / Launch** | Kid | The nightly choice: 🎲 Roll the dice · 6 option cards · ▶️ Continue · ⌨️/🎤 Request |
| **Story view** | Kid | Streaming chapter text + voice playback controls; calm, auto-dimming |
| **Archive** | Kid | Past episodes of a series, each with a short summary; tap to re-read/replay aloud |
| **Onboarding quiz** | Kid + parent | Seed the story world; full first-run + mini-quiz per new series; optional **Parent's Brief** |
| **Settings** (gated) | Parent | Age, detail level, intensity, language, **banned themes**, **Parent's Brief**, AI provider + key, **safety reviewer (on by default)**, voice provider, theme |
| **Interests** (gated) | Parent | Add/toggle/weight "new interests" |
| **Profiles admin** (gated) | Parent | Create/edit/delete child accounts |

## Home screen — the heart

```
┌─────────────────────────────────────────┐
│   🌙  Good evening, Aiden!                │
│                                           │
│        ┌───────────────────────┐          │
│        │   ▶️  Continue our      │          │
│        │      story…            │   ← if a saga exists
│        └───────────────────────┘          │
│                                           │
│   ┌────────┐  or pick a path:             │
│   │  🎲    │   [card1][card2][card3]       │
│   │  Roll  │   [card4][card5][card6]   ← twist deck
│   └────────┘                              │
│                                           │
│   ⌨️ Type a story idea…   🎤 (hold to talk) │
└─────────────────────────────────────────┘
```

The 6 cards are a **random hand drawn from the ~50-card localized twist deck**, re-dealt each time the creator opens so the choices stay fresh; the dice picks from the whole deck at random with a fun animation. The text/mic input feeds the safety-guarded request path.

## Starting a new series — theme chooser

When a kid branches a new series they pick **up to 3 themes** (the flavors of the whole storyline), then a hero, then answer a short mini-quiz. There are a lot of themes, so the chooser is **grouped** into a few friendly buckets (kid taps a bucket → sees its cards) to avoid an overwhelming grid:

**🚀 Exciting** — 🗺️ Adventure · 🔍 Mystery · 🦸 Superhero
**🌙 Calm & Bedtime** — 🌙 Cozy / Dreamtime · 🧘 Mindfulness / Calm · 💛 Feelings & Kindness · 🏡 Slice-of-Life / Helper
**🔬 Discover & Learn** — 🌿 Nature · ⚙️ Technical · 🎬 Documentary · 📚 Learning · ⏳ History / Time-Travel · 🌍 Around the World
**✨ Imagine & Giggle** — 🏰 Fairytale / Folktale · 😄 Silly / Giggles
**🎲 Surprise** (AI picks) · **✏️ Custom** (free-text — any flavor, e.g. "pirate cooking school")

| Theme | Flavor the story leans into |
|-------|-----------------------------|
| 🗺️ **Adventure** | Quests, exploration, brave-but-cozy stakes |
| 🔍 **Mystery** | Gentle, age-appropriate puzzle-solving — page-turny, never scary |
| 🦸 **Superhero** | Everyday-hero stories (helping, courage), not combat |
| 🌙 **Cozy / Dreamtime** | Slow, soft, sleepy, low-stakes — the flagship wind-down flavor |
| 🧘 **Mindfulness / Calm** | Breathing, gratitude, gentle imagery — doubles as a sleep aid |
| 💛 **Feelings & Kindness** | Social-emotional: empathy, big feelings, sharing |
| 🏡 **Slice-of-Life / Helper** | Everyday situations that model routines (first day of school, doctor visit) |
| 🌿 **Nature** | Animals, ecosystems, the outdoors, gentle wonder |
| ⚙️ **Technical** | How things work — machines, building, simple engineering/coding ideas |
| 🎬 **Documentary** | A friendly narrator explains *real* things accurately (nature-doc style) |
| 📚 **Learning** | Teaches a concept (counting, science, reading) *through* the story |
| ⏳ **History / Time-Travel** | Visit the past; sneaky-educational, pairs with Documentary/Learning |
| 🌍 **Around the World** | Cultures, geography, food — pairs great with Bilingual mode |
| 🏰 **Fairytale / Folktale** | Classic "once upon a time" storybook cadence |
| 😄 **Silly / Giggles** | Pure comedy and wordplay |
| 🎲 **Surprise / Mixed** | Let the AI pick the flavor |
| ✏️ **Custom** | Free-text — type any flavor |

Themes are pick-ordered: the first is the **lead** flavor, the other one or two **colour** it (a Mystery that's also Silly and about Nature). They're stored as `Series.theme` + `Series.extraThemes` and blended by `PromptBuilder` into a single instruction, so one story comes out — not three. The per-night **twist deck** still drives each episode's direction *within* those flavors. Theme cards are localized.

### Naming a story

Leave the story-name field blank and the model titles the story itself, from what actually happened in the first chapter (`story_title` in the structured output). Until then the story shows a placeholder; once named, the title sticks and is never overwritten. A name typed by a grown-up always wins.

## Worlds — the child's page vs. the grown-up's

A world page shows only what a child needs: the world's name, what it's about, its flavors, and the list of episodes. Everything that *changes future stories* — renaming the world, its premise, its themes, and the cast — lives behind **Edit world** (parent mode only).

Editing the cast is not a silent database change. Adding a character queues an **introduction**, and removing one queues a **send-off**: the next story writes them out warmly and on the page (they sail away, are called home, set off on their own adventure) so a child is never left wondering where a friend went. Illness, death, danger, and unexplained disappearance are explicitly forbidden. See [safety.md](safety.md).

### Deleting things

Anything that can't be undone — a world, a story, a chapter, a character — goes through **three** steps: the parent gate, a dialog naming exactly what will be lost, and a final "Are you sure?" double-check. Kids tap fast; nothing vanishes on one tap.

### Bilingual mode — a modifier on top of any theme

Separately from the theme, a new series can toggle **Bilingual mode** (a small switch in new-series setup): the story weaves in a **second language** so the kid soaks one up. Works with *any* theme — a bilingual Adventure, a bilingual Documentary, etc. Set the **second language** + a **blend level** (sprinkle / phrases / alternating). Stored as `bilingualEnabled` + `secondaryLanguage` + `bilingualBlend`. See [i18n.md](i18n.md) and [voice-tts.md](voice-tts.md).

## Theming / color config

- `ThemeData` driven by a per-child `themeColor` (seed color → Material 3 scheme).
- A small palette picker in Settings (curated, kid-pleasing presets + a few custom). Stored on the profile.
- Dark mode default for bedtime; respect a "night dim" toward the end of a story.
- Fonts: friendly, highly legible; ensure CJK coverage for Japanese (see [i18n.md](i18n.md)).

## Accessibility

- Scalable text, high-contrast option, large tap targets (≥48dp).
- Read-along highlighting (Phase 3+) doubles as an early-reader aid.
- Don't rely on color alone for meaning.

## Porting notes (PC → iOS touch)

- Use adaptive layouts (`LayoutBuilder`, breakpoints) not fixed pixel positions.
- Mouse hover is a bonus, never required; every action works by tap.
- Mic permission & secure storage differ per platform — isolated in adapters, not UI.
- Keep navigation shallow (kids get lost in deep menus).

## Microphone input

- 🎤 "hold to talk" → `SttProvider` → text → safety-guarded request path.
- Visible listening state + easy cancel. Permission handled per platform.
- Always fall back to typing if STT is unavailable.

## Phasing

Basic functional screens accompany each feature phase; visual polish, theming, and animation come together in **Phase 4/5**. See the [build plan](../build-plan/README.md).
