import '../../domain/models/beat.dart';
import '../../domain/models/series.dart';
import '../../domain/models/story_request.dart';
import '../../domain/models/story_segment.dart';
import 'ai_provider.dart';

/// A canned provider so the domain + UI can be built and demoed offline, with
/// no API key. Always returns a gentle, safe placeholder segment.
/// Real providers arrive in Phase 2. See `build-plan/phase-0-foundation.md`.
class FakeAiProvider implements AiProvider {
  const FakeAiProvider();

  @override
  ProviderId get id => ProviderId.fake;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<StorySegment> generate(StoryRequest request) async {
    final hero =
        request.series.heroName ??
        (request.series.heroMode == HeroMode.childAsHero
            ? request.child.displayName
            : 'a small brave friend');
    return StorySegment(
      storyText:
          'Once upon a quiet evening, $hero set off on a cozy little journey. '
          'The stars blinked hello, the moon hummed a soft tune, and '
          'everything felt calm and safe.\n\n'
          '(Placeholder story from the FakeAiProvider — real AI arrives in '
          'Phase 2.)',
      summary: '$hero began a gentle journey under friendly stars.',
      rating: AgeRating.tiny,
      setting: 'a calm evening under the stars',
      characters: [hero],
      openThreads: const ['Where will the journey lead tomorrow night?'],
    );
  }
}
