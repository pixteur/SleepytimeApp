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
}
