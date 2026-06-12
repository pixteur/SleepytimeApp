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
| **Story library** | Kid | Shelf of the child's **series**; continue one, or **branch off** a new series (with hero choice). |
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

The 6 cards come from the localized **twist deck**; the dice picks one at random with a fun animation. The text/mic input feeds the safety-guarded request path.

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
