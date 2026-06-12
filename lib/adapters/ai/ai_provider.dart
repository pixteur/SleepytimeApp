import '../../domain/models/story_request.dart';
import '../../domain/models/story_segment.dart';

/// A swappable AI backend. Claude/OpenAI/Gemini now (bring-your-own-key);
/// a `HostedProvider` drops in later behind this same interface — the story
/// engine never changes. See `docs/ai-providers.md`.
abstract class AiProvider {
  ProviderId get id;

  /// Generate the next story segment for a fully-built request.
  Future<StorySegment> generate(StoryRequest request);

  /// Whether this provider is configured (key present, reachable).
  Future<bool> isReady();
}

enum ProviderId { claude, openai, gemini, hosted, fake }
