import '../../domain/models/beat.dart';
import '../../domain/models/story_segment.dart';
import '../../domain/prompt_builder.dart';
import 'ai_provider.dart';

/// A canned provider so the domain + UI can be built and demoed offline, with
/// no API key. Always returns a gentle, safe placeholder segment (a real model
/// would personalise it from the prompt). Real providers arrive in Phase 2b.
/// See `build-plan/phase-2-story-engine.md`.
class FakeAiProvider implements AiProvider {
  const FakeAiProvider();

  @override
  ProviderId get id => ProviderId.fake;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<StorySegment> generate(StoryPrompt prompt) async {
    return const StorySegment(
      storyText:
          'Once upon a quiet evening, a small brave friend set off on a cozy '
          'little journey. The stars blinked hello, the moon hummed a soft '
          'tune, and everything felt calm and safe.\n\n'
          '(Placeholder story from the FakeAiProvider — a real model writes '
          'tonight\'s tale from the prompt in Phase 2b.)',
      summary: 'A gentle journey began under friendly stars.',
      rating: AgeRating.tiny,
      setting: 'a calm evening under the stars',
      characters: ['a small brave friend'],
      openThreads: ['Where will the journey lead tomorrow night?'],
    );
  }
}
