# 00 — Project Overview

## Vision

A warm, safe, magical nighttime ritual. A parent and child open SleepytimeApp, choose how tonight's story unfolds, and the app — narrated in a friendly voice — spins a fresh, age-appropriate adventure that remembers where they left off and grows with the child's interests.

## Core experience (the nightly loop)

1. **Pick a child profile** (one account per kid).
2. **Choose how tonight begins:**
   - 🎲 **Roll the dice** — a surprise twist drives the next chapter.
   - 6 **option cards** — pick a direction from a tunable "twist deck".
   - ▶️ **Continue** — resume the ongoing saga.
   - ⌨️ / 🎤 **Request it** — type or speak what they want to hear.
3. The **story engine** assembles the child's profile + interests + story history + the chosen twist, asks the AI for the next chapter, and **enforces the age rating** on the result.
4. The chapter is **displayed and read aloud** in an expressive character voice.
5. The new chapter is saved as a structured **story beat** so tomorrow night continues coherently.

## Pillars

| Pillar | What it means |
|--------|---------------|
| **Safe by design** | Age rating injected into every prompt + a guardrail pass on every output. Safety is enforced, not hoped for. See [safety.md](safety.md). |
| **Grows with the kid** | Age, reading level, tone, and a living "interests" list reshape stories over time. |
| **Coherent over time** | Stories persist as structured beats (characters, settings, open threads) so the saga remembers itself for weeks. |
| **Local & private** | All child data stays on-device. No accounts or servers required to use it. See [data-model.md](data-model.md). |
| **Delightful & personal** | Kid-friendly, touch-ready UI with color/theme customization. |
| **Portable** | Flutter core that runs PC → Mac → iOS by swapping only the platform edges. |

## Target platforms

1. **Windows** (primary build target — develop here)
2. **macOS** (port)
3. **iOS / iPad** (port — touch-first)

## Non-goals (for now)

- No social features, sharing, or multiplayer.
- No ads, no in-app data collection on children.
- No always-on backend at launch (kept optional/hosted-ready for the future product phase).

## Glossary

- **Beat** — one structured saved chapter (summary, characters, setting, open threads, age rating). The unit of story memory.
- **Twist deck** — the tunable set of story directions surfaced as the 6 option cards / dice rolls.
- **Seed** — the initial premise that starts a child's story world (from the onboarding quiz).
- **Interest nudge** — a new fascination added by the parent that biases future stories.
- **Provider** — a swappable AI backend (Claude / OpenAI / Gemini, or a future hosted service).

## Related docs

- [architecture.md](architecture.md) · [safety.md](safety.md) · [data-model.md](data-model.md) · [ai-providers.md](ai-providers.md) · [voice-tts.md](voice-tts.md) · [i18n.md](i18n.md) · [ui-ux.md](ui-ux.md) · [decision-log.md](decision-log.md)
- Exporting out of the app: [lunii-export.md](lunii-export.md) · [distribution.md](distribution.md)
- Where the product goes next: [flam-study.md](flam-study.md) — a study of Lunii's FLAM and a spec for interactive "Adventure mode" stories.
