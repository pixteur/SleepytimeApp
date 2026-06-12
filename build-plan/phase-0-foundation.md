# Phase 0 — Foundation

**Goal:** A running, empty Flutter Windows app with the architecture skeleton, dependencies, and CI in place. No features yet — just a solid floor to build on.

## Tasks

### Toolchain (must do first — not currently installed)
- [ ] Install **Flutter SDK** (stable) + add to PATH. `flutter doctor` until green for Windows.
- [ ] Install **Visual Studio** (Desktop C++ workload) — required for Windows desktop builds.
- [ ] Enable Windows desktop: `flutter config --enable-windows-desktop`.
- [ ] Confirm an editor setup (VS Code + Flutter/Dart extensions, or Android Studio).

### Project scaffold
- [ ] `flutter create` the app in-repo (org id, app name `sleepytime`).
- [ ] Add the folder structure from [../docs/architecture.md](../docs/architecture.md) (`ui/`, `domain/`, `adapters/`, `l10n/`, `theme/`).
- [ ] Add dependencies: `flutter_riverpod` (state/DI), `drift` + `sqlite3_flutter_libs` (or `isar`) (storage), `flutter_secure_storage` (keys), `flutter_localizations` + `intl` (i18n), `http`/`dio` (AI calls), `flutter_tts` (voice), `uuid`, `freezed`+`json_serializable` (models). Pin versions.
- [ ] Wire **Riverpod** at the root; a trivial provider proving DI works.

### Architecture skeleton (interfaces only, no real impls)
- [ ] Define interfaces: `AiProvider`, `TtsProvider`, `SttProvider`, `StorageRepo`, `SecretStore`.
- [ ] Define core models (stubs): `ChildProfile`, `Beat`, `Interest`, `StoryRequest`, `StorySegment`.
- [ ] A `FakeAiProvider` returning canned text (so domain/UI can be built without a key).
- [ ] App boots to a placeholder Home screen.

### Quality gates
- [ ] `flutter analyze` clean; set up `analysis_options.yaml` (lints).
- [ ] First unit test passing (`test/` runs).
- [ ] **CI**: GitHub Actions (or local script) running `flutter analyze` + `flutter test` on push.
- [ ] Pre-commit: format + analyze.

### Docs
- [ ] Update README "Getting started" once `flutter run -d windows` works.
- [ ] Log decisions (DB choice once made) in [../docs/decision-log.md](../docs/decision-log.md).

## Exit criteria
- `flutter run -d windows` shows a placeholder Home screen.
- `flutter analyze` + `flutter test` pass in CI.
- All adapter interfaces + a `FakeAiProvider` exist so later phases can build offline.

## Notes
- Decide **Drift vs Isar** here or defer to Phase 2 — but stub `StorageRepo` either way.
- Don't over-build. This phase is a *floor*, not features.
