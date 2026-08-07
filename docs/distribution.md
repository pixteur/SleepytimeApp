# Distribution & installers

Goal: a double-click installer that auto-sets-up on **Windows** and **macOS**.
(API keys are still entered in-app by the parent — we never bundle secrets.)

## Windows — MSIX

Config lives in `pubspec.yaml` under `msix_config`. Build:

```powershell
pwsh scripts/build_windows_installer.ps1
# → build/windows/x64/runner/Release/sleepytime.msix
```

The script runs `dart run msix:build` (release build + manifest) then packs with
the **Windows SDK's** `makeappx.exe`. We use the SDK packer because the `msix`
package's *bundled* `makeappx.exe` can fail with a "side-by-side configuration
is incorrect" error on some machines. (`dart run msix:create` alone works where
the bundled packer is healthy.)

**Signing (required to install on other machines):**
- Testing: a self-signed cert — `msix` can generate one (`--install-certificate`),
  or create one with `New-SelfSignedCertificate` and `signtool sign` the `.msix`.
  Users must trust the cert once.
- Release: an EV/OV code-signing certificate, or ship via the **Microsoft Store**
  (MSIX is Store-native).

## macOS — .dmg / .pkg (needs a Mac)

Not yet buildable here — there's no `macos/` folder. On a Mac:

```bash
flutter create --platforms=macos .     # add macOS scaffolding (one-time)
flutter build macos --release          # → build/macos/Build/Products/Release/Sleepytime.app
```

Then package + distribute:
- **.dmg** (drag to Applications): `create-dmg`, or `flutter_distributor` (target `dmg`).
- **Codesign + notarize** with an Apple **Developer ID** (`codesign`, `xcrun notarytool`)
  or users hit Gatekeeper. App Store distribution uses a `.pkg` + App Store Connect.

## One-config multi-platform — flutter_distributor

`distribute_options.yaml` defines a `prod` release (msix + dmg):

```bash
dart pub global activate flutter_distributor
flutter_distributor release --name prod
```

Run the Windows job on Windows, the macOS job on a Mac (per-platform build hosts).

## Audio format (future-proofing storage)

Narration size is dominated by the provider's audio format, not our packaging:

- **OpenAI TTS / ElevenLabs** already return **compressed** audio (MP3, ~1 MB/chapter)
  — we store it as-is. OpenAI can also return `opus`/`aac` via `response_format`.
- **Gemini TTS** returns **uncompressed 24 kHz WAV** (~8 MB/chapter) — the outlier.
  We gzip it in the background (lossless, ~20%; see `audio_compression.dart`).

**Best path for small, mobile-friendly audio:** prefer a provider that returns
compressed audio (OpenAI/ElevenLabs), or — to keep Gemini's voice — add a native
**AAC/Opus** encoder later via platform channels (AVAudioConverter on iOS/macOS,
MediaCodec on Android). AAC gives universal hardware decode; Opus gives the best
quality-per-byte for speech (~8–12× smaller than WAV).
