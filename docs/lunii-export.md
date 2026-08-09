# Exporting to a Lunii storyteller

A story the app has generated can be sent to a **Lunii** ("Ma Fabrique à
Histoires") — the screen-free storyteller box — so a child can listen to it
away from the tablet or PC.

Lunii's own pack format is encrypted and device-keyed, so the app does not
write it directly. Instead it writes the **STUdio archive pack**, the editable
format used by the open-source [STUdio](https://marian-m12l.github.io/studio-website/)
tool, which handles the transfer and the conversion to whatever your firmware
expects.

## Using it

1. In the app: **parent mode on** → open the story → the share menu (↥) →
   **Lunii story pack (parents)**.
2. The pack lands in `<Documents>/Sleepytime/lunii/<Story name>.zip`.
3. Open STUdio, drag the zip into the library, plug in the Lunii, transfer.

The narration must already be **saved on the device** — play the story through
or tap the cloud icon on each chapter first. The export only bundles audio it
finds in the cache; with none, it tells you so rather than writing a silent
pack.

> **Known bug — the export cannot find cued narration.** Playback caches audio
> **per chunk**, keyed by the chunk's text *plus its narration cue*. Every audio
> export — this one, the audiobook, and `.sleepy` with audio — still asks for a
> single key built from the whole chapter text, which nothing writes once a
> chapter has cues. Chapters written before narration cues (one chunk, no cue)
> still export fine, which is why this hid: the bundled demo works, and anything
> the editorial pass has touched silently exports nothing.
>
> Measured with `dart run tool/export_keys_check.dart all`:
>
> ```
> Obsidian Stone      chapters=11  playback-cached=11  export-would-find=11
> Ashi's adventure    chapters=6   playback-cached=4   export-would-find=0
> ```
>
> The fix is to give the chapter→cache-key mapping one home (chunker + cue
> suffix) that both `CloudTtsProvider` and `SleepyService` use, and to
> concatenate a chapter's chunks on export. `.sleepy` additionally needs to
> carry the chunks separately so an imported story is playable, which means the
> manifest must carry each chapter's narration notes too.

## What the pack contains

```
<Story name>.zip
├── story.json          the node graph + pack metadata
└── assets/
    ├── cover.bmp       320×240 night sky (generated, see below)
    ├── chapter-01.wav  narration, straight from the audio cache
    └── …
```

A Lunii story is a graph of two node types: **stage** nodes play an audio file
and show an image, and **action** nodes are the links between them. We emit a
straight line:

```
cover ─OK─▶ chapter 1 ─▶ chapter 2 ─▶ … ─▶ chapter n
```

- The **cover** waits for OK (no autoplay), so the box doesn't start talking
  the moment it's selected.
- Each **chapter** has `autoplay` on, so the story runs to the end by itself.
  OK skips to the next chapter, pause works, and home backs out to the pack
  list. The last chapter has no onward link, which ends the story.
- The wheel is off throughout: it picks between an action node's options, and a
  bedtime story doesn't offer choices. (A chapter picker would need a short
  spoken prompt recorded per chapter.)

## Format notes

These are the constraints STUdio's `ArchiveStoryPackReader` actually enforces,
which is what [lunii_pack.dart](../lib/adapters/export/lunii_pack.dart) targets:

- `story.json` at the zip root; assets under `assets/`.
- Asset **filenames are arbitrary** — nodes reference them by name and STUdio
  picks the codec from the extension (`.wav` `.mp3` `.ogg` / `.bmp` `.png`
  `.jpg`). STUdio's own tooling names them by SHA-1; we use readable names.
- `version`, `format`, and all five `controlSettings` booleans are required.
- Audio is passed through **unconverted**. STUdio resamples on transfer
  (`anyToWave` → 32 kHz mono 16-bit), so Gemini's 24 kHz WAV and OpenAI's /
  ElevenLabs' MP3 are all fine as-is.
- Images are 320×240. [cover_image.dart](../lib/adapters/export/cover_image.dart)
  draws one in pure Dart — a night sky with a crescent moon, star field seeded
  from the story title so a given story always gets the same sky. No image
  package, no font rendering, no bundled asset to keep in sync.

## Related exports

| Format | What it's for |
|--------|---------------|
| `.sleepy` | The app's own bundle (text + audio) — re-import on another device |
| `.sleepy` text-only | Send by message/email; the recipient's app rebuilds the voice |
| Audiobook | One joined audio file + metadata sidecar, for a phone or car |
| Lunii pack | This document |
