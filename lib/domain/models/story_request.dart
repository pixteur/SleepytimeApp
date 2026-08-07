import 'beat.dart';
import 'child_profile.dart';
import 'interest.dart';
import 'series.dart';

/// Everything the (future) PromptBuilder assembles for one story turn.
/// The `AiProvider` translates this into its own wire format.
/// See `docs/architecture.md` and `docs/ai-providers.md`.
class StoryRequest {
  const StoryRequest({
    required this.child,
    required this.series,
    required this.intent,
    this.recentBeats = const [],
    this.interests = const [],
    this.chosenTwist,
    this.chapterNumber = 1,
    this.maxChapters = 6,
    this.worldPremise = '',
    this.cast = const [],
  });

  final ChildProfile child;
  final Series series;
  final StoryIntent intent;

  /// Recent context for "continue where we left off" (assembled by BeatStore).
  final List<Beat> recentBeats;
  final List<Interest> interests;

  /// The option/dice/typed request that drove this turn, if any.
  final String? chosenTwist;

  /// 1-based chapter index, so the model can pace a complete multi-chapter story.
  final int chapterNumber;

  /// Hard upper bound on chapters, so a story always ends (and never burns
  /// through API quota generating endlessly when the model won't conclude).
  final int maxChapters;

  /// True on/after the last allowed chapter — the model must wrap up now.
  bool get mustConclude => chapterNumber >= maxChapters;

  /// The world/universe premise this episode belongs to (empty for standalone).
  final String worldPremise;

  /// Recurring characters (one prompt line each) to keep consistent across the
  /// whole universe, e.g. "Splat — a big black cat who loves adventures".
  final List<String> cast;
}
