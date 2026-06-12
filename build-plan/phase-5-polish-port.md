# Phase 5 — Polish & Port

**Goal:** Make it feel magical and ship it beyond Windows — macOS and iOS from the same Flutter codebase.

## Tasks

### UX polish
- [ ] Dice-roll animation, card transitions, gentle ambient motion.
- [ ] Sound/music option (soft background, mutable).
- [ ] Onboarding flow polish; empty/first-run states.
- [ ] Accessibility pass: text scaling, contrast, tap targets, screen-reader labels.
- [ ] Performance: smooth on lower-end hardware; responsive while generating (streaming if not already).

### macOS port
- [ ] `flutter config --enable-macos-desktop`; build & run.
- [ ] macOS `SecretStore` (Keychain) + TTS engine verification.
- [ ] Notarization/signing basics for distribution.

### iOS / iPad port
- [ ] `flutter build ios`; run on simulator + device.
- [ ] Touch-tune all layouts (already touch-first — verify, don't redesign).
- [ ] iOS Keychain `SecretStore`, iOS TTS/STT, mic permission strings.
- [ ] App icons, splash, safe-area handling.
- [ ] TestFlight build.

### Packaging / distribution
- [ ] Windows installer (MSIX or similar).
- [ ] Versioning + release notes process.
- [ ] Crash/error logging (privacy-respecting; no child content).

## Exit criteria
- A polished build runs on Windows, macOS, and iOS from one codebase, with platform-correct secure storage, TTS/STT, and permissions.
- Distributable artifacts exist for at least Windows + a TestFlight iOS build.

## Dependencies
- Phases 0–4.

## Notes
- The whole architecture was chosen to make this phase cheap — porting should be adapters + layout tuning, not rewrites. If it isn't, revisit where platform logic leaked into UI/domain.
