# Narration cues

The editorial second pass ([story-quality.md](story-quality.md)) has the
finished prose in front of it, so it also writes the **direction for the
narrator**: how the chapter should sound when a voice model reads it aloud.

## The rule that shapes everything else

**Direction never goes inside `story_text`.**

That string is displayed on screen, written into the Lunii pack and `.sleepy`
exports, and used as the audio-cache key. And a voice engine handed markup it
does not recognise does not skip it — it *reads it out loud*. A child hearing
"bracket whispers bracket" is a worse outcome than no direction at all.

So cues are **semantic, never syntactic**. The model writes `pace=slow`, never
`<break time="1s"/>` or `[whispers]`. One pass produces one set of cues, and
each adapter translates them into its own dialect — which is what makes a
single refinement pass serve every voice provider.

## What the pass returns

Three fields, alongside the story:

| Field | Shape | Meaning |
|---|---|---|
| `narration_style` | string | One line for the whole chapter — "unhurried and close, like a parent at the bedside". |
| `character_voices` | string[] | How the **same** narrator colours each character — "Leo — precise and warm, with a soft metallic edge". |
| `narration_cues` | string[] | One entry per paragraph, in order. |

Each cue is plain `key=value` pairs: `pace`, `emotion`, `volume`, `note`.

```
pace=slow; emotion=wistful; volume=hushed; note=linger on the last line
```

An empty entry means "read this plainly", which is right for most of a story.

## Why one narrator, not many

Gemini's TTS has a native multi-speaker mode, and ElevenLabs has dialogue
features — but they cap out at a couple of speakers, differ per provider, and
would fragment the pipeline. A single narrator shifting tone works on every
engine, and at bedtime it is the better choice anyway: hard voice switches jolt
a child who is settling. `character_voices` therefore describes colouring, never
casting.

## Why cues are per paragraph, not per line

The reader already streams paragraph by paragraph, so cue *n* lands on paragraph
*n* with no new chunking logic.

Going finer is possible but counterproductive as a *request* boundary: voice
models generate intonation across a whole utterance, so one request per sentence
makes every sentence restart cold and the reading turns choppy. Sub-paragraph
shaping lives in the cue's `note` instead — "linger on the last line" — and, on
engines with inline tags, can be rendered at sentence boundaries *within* the
one request.

## Misalignment degrades to plain reading

A model asked for one cue per paragraph will sometimes return the wrong number.
`NarrationNotes.cueAt` returns an empty cue for any index it does not have, so a
short list means later paragraphs are read plainly. It never shifts the list up
and reads paragraph 4 with paragraph 9's direction — wrong direction is worse
than none, and much harder to notice.

The chapter-wide `narration_style` applies regardless, so even a completely
misaligned cue list leaves the reading in the right register.

## Rendering, per provider

| Provider | Model | How the cue is applied |
|---|---|---|
| OpenAI | `gpt-4o-mini-tts` | `instructions` — already sent, currently hardcoded |
| Gemini | `gemini-2.5-flash-preview-tts` | Natural-language style prefix on the text part |
| ElevenLabs | `eleven_multilingual_v2` | `voice_settings` plus `<break>`; inline audio tags need a v3 model |
| Windows | `flutter_tts` | `pace` mapped to speech rate |

## The cache key

The audio cache is keyed on `(voiceSignature, language, text)`. A cue changes
the audio **without changing a word of the text**, so the cue has to be folded
into that key — otherwise a re-refined chapter serves the previous reading from
cache and the new direction is silently ignored. `NarrationCue.encode()` exists
for exactly this and round-trips through `NarrationCue.parse`.
