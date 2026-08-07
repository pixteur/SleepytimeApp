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
