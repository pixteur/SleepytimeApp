import '../../domain/models/beat.dart';
import '../../domain/models/story_segment.dart';
import '../../domain/prompt_builder.dart';
import 'ai_provider.dart';

/// A canned provider so the domain + UI can be built and demoed offline, with no
/// API key. Produces a short, varied 3-chapter placeholder (different text per
/// chapter, ending on chapter 3) so the flow is coherent without a key — a real
/// model writes unique, longer tales. See `build-plan/phase-2-story-engine.md`.
class FakeAiProvider implements AiProvider {
  const FakeAiProvider();

  @override
  ProviderId get id => ProviderId.fake;

  @override
  Future<bool> isReady() async => true;

  static const List<String> _bodies = [
    'Once upon a quiet evening, a small brave friend set off on a cozy little '
        'journey. The stars blinked hello and the moon hummed a soft, sleepy '
        'tune.\n\n'
        'Down a winding path of moonlight they wandered, past whispering grass '
        'and a pond as smooth as glass, wondering what gentle adventure waited '
        'ahead.\n\n'
        '(This is placeholder chapter 1 — add a story AI key in Settings for '
        'real, unique stories.)',
    'The next part of the journey led to a friendly little clearing where '
        'fireflies drew slow, glowing circles in the dark.\n\n'
        'A kind old owl shared a warm cup of starlight tea, and together they '
        'told soft stories until the night felt cozy and safe.\n\n'
        '(Placeholder chapter 2.)',
    'At last the path curved gently home. The small brave friend yawned a '
        'great big yawn, tucked under a blanket of moonbeams, and felt happy '
        'and calm.\n\n'
        'The stars dimmed one by one, the moon whispered goodnight, and '
        'everyone drifted off into the softest, sweetest sleep.\n\n'
        '(Placeholder chapter 3 — the end.)',
  ];

  static const List<String> _summaries = [
    'A small friend set off on a cozy moonlit journey.',
    'A clearing of fireflies and starlight tea with a kind owl.',
    'The gentle path home and a peaceful goodnight.',
  ];

  @override
  Future<StorySegment> generate(StoryPrompt prompt) async {
    final chapter = _chapterFrom(prompt.system);
    final index = (chapter - 1).clamp(0, _bodies.length - 1);
    final isFinal = chapter >= _bodies.length;
    return StorySegment(
      storyText: _bodies[index],
      summary: _summaries[index],
      rating: AgeRating.tiny,
      setting: 'a calm, starlit night',
      characters: const ['a small brave friend'],
      openThreads: isFinal
          ? const []
          : const ['Where will the path lead next?'],
      isFinal: isFinal,
    );
  }

  int _chapterFrom(String system) {
    final match = RegExp(
      r'chapter (\d+)',
      caseSensitive: false,
    ).firstMatch(system);
    return match != null ? int.parse(match.group(1)!) : 1;
  }
}
