import '../../domain/models/story_segment.dart';
import '../../domain/prompt_builder.dart';

/// A swappable AI backend. Claude/OpenAI/Gemini now (bring-your-own-key);
/// a `HostedProvider` drops in later behind this same interface — the story
/// engine never changes. The engine builds the [StoryPrompt] (via PromptBuilder,
/// the single source of truth); providers only translate it to their wire
/// format and parse the structured result. See `docs/ai-providers.md`.
abstract class AiProvider {
  ProviderId get id;

  /// Generate the next story segment for a fully-built prompt.
  Future<StorySegment> generate(StoryPrompt prompt);

  /// Whether this provider is configured (key present, reachable).
  Future<bool> isReady();
}

enum ProviderId { claude, openai, gemini, hosted, fake }
