# Phase 4 — i18n & Theming

**Goal:** Full French & Spanish, Japanese framework support, and rich color/theme personalization. See [../docs/i18n.md](../docs/i18n.md) and [../docs/ui-ux.md](../docs/ui-ux.md).

## Tasks

### Internationalization
- [ ] Audit: ensure **no hardcoded UI strings** remain (pseudo-localization pass).
- [ ] Complete ARB files: `en`, `fr`, `es` (full); `ja` (framework + initial coverage).
- [ ] Localize the **twist deck** content and quiz copy.
- [ ] Story generation in-language verified per locale (natural, not translated); structured metadata stored in story language.
- [ ] Verify voices per language; wire cloud-TTS fallback where device voices are missing (esp. Japanese).
- [ ] Bundle/verify a CJK-capable font (e.g. Noto Sans JP).
- [ ] Locale resolution: active child → device → `en`.
- [ ] Don't hardcode LTR (keep RTL-addable later).

### Theming / personalization
- [ ] Per-child `themeColor` → Material 3 seed scheme.
- [ ] Curated palette picker (kid-pleasing presets + a few custom) in Settings.
- [ ] Dark/bedtime mode + "night dim" toward story end.
- [ ] Avatar set expansion.

### Testing
- [ ] Smoke test per launch language: profile → one beat → UI + story + voice all in-language.
- [ ] Layout overflow checks across languages.

## Exit criteria
- App fully usable in en/fr/es with localized UI, stories, and voices; Japanese works end-to-end for at least a basic flow.
- Each child can personalize color/theme; changes persist.

## Dependencies
- Phases 1–3 (UI surfaces and voice exist to localize/theme).

## Notes
- i18n externalization should already be in place from Phase 0/1 — this phase *fills in* languages and polishes, not retrofits.
