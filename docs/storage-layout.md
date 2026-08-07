# On-device storage layout

All persistent app data lives under the user's **Documents** directory (via
`path_provider`). Story assets are consolidated in one **library** tree so they
are easy to find, back up, and share.

```
<Documents>/
├── sleepytime.sqlite        Drift database: profiles, worlds, characters,
│                            series (episodes), beats (chapters), learned profile
└── Sleepytime/              the story library (see lib/adapters/storage/library_paths.dart)
    ├── audio/               cached narration — one file per (voice + language + chapter text),
    │                        content-addressed; lets a story replay offline with no API calls
    ├── stories/             exported .sleepy bundles (text + audio + metadata)
    └── images/              story covers / character art (reserved for future use)
```

Other stores:

- **Secrets** (AI/voice API keys): OS-secure storage — Windows DPAPI blob in
  SharedPreferences; iOS/macOS Keychain when those platforms are added. Never in
  the library. See `docs/ai-providers.md`.
- **Preferences** (consent flag, selected provider/voice, parent mode): the
  platform `shared_preferences` store.

## Notes

- `LibraryPaths` (`lib/adapters/storage/library_paths.dart`) is the single source
  of truth for these folders; create/resolve them there, not ad hoc.
- The audio cache key is a stable FNV-1a hash of `voiceSignature|language|text`,
  so a re-listen (or an imported `.sleepy` on the same voice) is a cache hit.
- The library is app-private on mobile (iOS/Android sandbox). For phone sharing,
  add `share_plus` / `file_picker` to move `.sleepy` files in and out of the
  native share sheet — see the `.sleepy` note in `docs/decision-log.md`.
