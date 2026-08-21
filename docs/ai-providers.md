# AI Providers

## Strategy

**Multi-provider, bring-your-own-key for development → hosted-ready for the product.** The app talks to one interface (`AiProvider`); Claude, OpenAI, and Gemini are implementations a parent enables by pasting their own key. A future `HostedProvider` (we hold the keys, we bill) is *just another implementation* of the same interface — the story engine never changes.

> Default provider: **Claude** (strong, reliable adherence to safety constraints — which matters a lot for a kids' app). Model IDs and API details: see the bundled **claude-api** skill rather than hardcoding from memory.

## The interface

```dart
abstract class AiProvider {
  /// Generate the next story segment for a fully-built request.
  /// Implementations must request the structured metadata
  /// (rating, sensitiveFlags, summary, characters, openThreads)
  /// that SafetyGuard and BeatStore depend on.
  Future<StorySegment> generate(StoryRequest request);

  /// Whether this provider is configured (key present, reachable).
  Future<bool> isReady();

  ProviderId get id; // claude | openai | gemini | hosted
}
```

`StoryRequest` carries the assembled system prompt, the context (seed + recent beats + interests), the chosen twist/intent, language, and detail level. `PromptBuilder` produces it; providers only translate it to their wire format. This keeps "how we prompt" in **one** place ([architecture.md](architecture.md)).

## Structured output

We need machine-readable metadata alongside the prose (for safety + beat continuity). Each provider impl asks for it in its native idiom:

- **Claude** — tool use / structured output.
- **OpenAI** — JSON mode / function calling / structured outputs.
- **Gemini** — function calling / response schema.

Target shape (provider-agnostic):

```json
{
  "story_text": "…the chapter, in the child's language…",
  "story_title": "a 2–6 word title for the whole story, from its content",
  "summary": "one-line recap",
  "rating": "tiny|little|big|older",
  "sensitive_flags": [],
  "characters": [{"name": "…", "note": "…"}],
  "setting": "…",
  "open_threads": ["…"]
}
```

If a provider returns malformed output, the adapter retries once, then surfaces a typed error the engine handles gracefully (fall back to a safe filler beat — never crash bedtime).

## Key management

- Parent pastes a key in Settings → stored via `SecretStore` (OS secure storage), never in the DB, never logged, never committed.
- Per-provider keys; the active provider is a setting.
- A "Test connection" button calls `isReady()`.

## Choosing a model

Story and voice models are both picked in the grown-up settings, from a list the
provider itself supplies — `GET /v1/models` (Anthropic, OpenAI, ElevenLabs) or
`GET /v1beta/models` (Google). A hard-coded id is wrong twice: the day it is
retired, and every day a better one exists that we have not shipped a release to
reach. See [model_catalog.dart](../lib/adapters/ai/model_catalog.dart).

One directory per **vendor**, not per role — a vendor's list covers both jobs,
so the same call fills the story dropdown and the voice dropdown.

**The list is a suggestion, never a gate.** No key, no network, or a refusal
falls back to typing an id by hand, and a hand-typed value that the list does
not carry stays selected. A brand-new model id is precisely when the list is
behind.

### What the hints may say

Only what the response or the id supports:

| Hint | Where it comes from |
|------|--------------------|
| `Speaks text aloud` | ElevenLabs' `can_do_text_to_speech`; a `tts` id elsewhere |
| `Most capable` / `Balanced` / `Fastest` | The tier named in the id — opus/sonnet/haiku, pro/flash/flash-lite |
| `Preview — tighter daily limits` | `preview`/`exp`/`beta` in the id |
| ElevenLabs prose | The vendor's own `description`, clipped to a line |

A note is a claim about what a model is good at, so it is computed **from the
classification**, never beside it.

### The trap this walked into

Google's image, music, robotics and computer-use models all answer
`generateContent`. Classifying on that alone offered `lyria-3-pro-preview` — a
music generator — as a story writer, and because "pro" is in the name described
it as *"most capable — best prose"*. Unit tests could not catch it: they parsed
responses we wrote ourselves. `dart run tool/model_catalog_probe.dart` asks the
real APIs with the saved keys and prints how each model is classified; the ids
it returned are now a test case.

A key can also be allowed to *use* models but not *list* them — a real
ElevenLabs key returns 401 `models_read` while narrating perfectly well. That
gets its own message, because "your key is wrong" would send a parent off
replacing a key that works.

## Cost & UX considerations

- **Streaming** (optional, Phase 2/3): show text as it writes and begin narration on sentence boundaries for a magical "live" feel.
- **Caching / context strategy** keeps per-night token use sane — see [data-model.md](data-model.md). With Claude, prompt caching of the stable system+seed portion is worth exploring.
- **Offline / no-key fallback:** a small bank of pre-written stories so the app still does *something* without a configured provider (great for first-run and demos).
- **Detail level** maps to target length/max tokens.

## Failure handling (bedtime must never break)

| Failure | Response |
|---------|----------|
| No key / not ready | Prompt parent to add a key; offer offline pre-written story |
| Network error / timeout | Retry w/ backoff (bounded); then offline fallback |
| Malformed structured output | Retry once; then fallback |
| Safety fail after retries | Safe "cozy filler" beat (see [safety.md](safety.md)) |

## Future: HostedProvider (Phase 6)

A thin client to our own service that holds provider keys, does server-side safety, billing/quotas, and (optionally) higher-quality voices. Same `AiProvider` interface → drop-in. See [build-plan/phase-6-hosted-backend.md](../build-plan/phase-6-hosted-backend.md).

> ⚠️ When implementing any Claude/Anthropic call, consult the **claude-api** skill for current model IDs, pricing, structured-output, and caching specifics instead of relying on memory.
