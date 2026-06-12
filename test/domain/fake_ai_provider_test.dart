import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/adapters/ai/ai_provider.dart';
import 'package:sleepytime/adapters/ai/fake_ai_provider.dart';
import 'package:sleepytime/domain/models/beat.dart';
import 'package:sleepytime/domain/models/child_profile.dart';
import 'package:sleepytime/domain/models/series.dart';
import 'package:sleepytime/domain/models/story_request.dart';
import 'package:sleepytime/domain/story_engine.dart';

void main() {
  const child = ChildProfile(id: 'c1', displayName: 'Aiden', age: 5);
  const series = Series(
    id: 's1',
    childId: 'c1',
    title: 'Test Saga',
    theme: StoryTheme.cozy,
    heroMode: HeroMode.childAsHero,
  );
  const request = StoryRequest(
    child: child,
    series: series,
    intent: StoryIntent.dice,
  );

  group('FakeAiProvider', () {
    test('is always ready and identifies as fake', () async {
      const provider = FakeAiProvider();
      expect(provider.id, ProviderId.fake);
      expect(await provider.isReady(), isTrue);
    });

    test('returns a safe, non-empty segment using the hero name', () async {
      const provider = FakeAiProvider();
      final segment = await provider.generate(request);

      expect(segment.storyText, contains('Aiden')); // childAsHero
      expect(segment.summary, isNotEmpty);
      expect(segment.rating, AgeRating.tiny);
      expect(segment.characters, contains('Aiden'));
    });
  });

  group('StoryEngine', () {
    test('takeTurn delegates to the provider (Phase 0 pass-through)', () async {
      const engine = StoryEngine(FakeAiProvider());
      final segment = await engine.takeTurn(request);
      expect(segment.storyText, isNotEmpty);
    });
  });

  group('AgeBand', () {
    test('maps ages to the right bands', () {
      expect(AgeBand.forAge(3), AgeBand.tiny);
      expect(AgeBand.forAge(6), AgeBand.little);
      expect(AgeBand.forAge(9), AgeBand.big);
      expect(AgeBand.forAge(12), AgeBand.older);
    });
  });
}
