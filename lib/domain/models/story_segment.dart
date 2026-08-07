import 'beat.dart';

/// The structured result an `AiProvider` returns for one turn — prose plus the
/// metadata `SafetyGuard` and `BeatStore` depend on. See `docs/ai-providers.md`.
class StorySegment {
  const StorySegment({
    required this.storyText,
    required this.summary,
    required this.rating,
    this.suggestedTitle = '',
    this.setting = '',
    this.sensitiveFlags = const [],
    this.characters = const [],
    this.openThreads = const [],
    this.isFinal = false,
  });

  /// The episode, in the child's language.
  final String storyText;

  /// One-line recap (feeds context windows + the archive list).
  final String summary;

  /// The model's self-reported age rating (validated by SafetyGuard).
  final AgeRating rating;

  /// A short title for the whole story, drawn from what actually happened.
  /// Used to name a story the grown-up left unnamed. See `StoryEngine`.
  final String suggestedTitle;
  final String setting;

  /// Any sensitive elements the model flagged.
  final List<String> sensitiveFlags;
  final List<String> characters;
  final List<String> openThreads;

  /// True on the last chapter — a warm, complete ending. Drives auto-generation.
  final bool isFinal;
}
