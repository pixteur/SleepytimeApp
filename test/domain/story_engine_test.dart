import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/adapters/ai/ai_provider.dart';
import 'package:sleepytime/adapters/ai/fake_ai_provider.dart';
import 'package:sleepytime/domain/models/beat.dart';
import 'package:sleepytime/domain/models/child_profile.dart';
import 'package:sleepytime/domain/models/series.dart';
import 'package:sleepytime/domain/models/story_segment.dart';
import 'package:sleepytime/domain/prompt_builder.dart';
import 'package:sleepytime/domain/story_engine.dart';

import '../support/in_memory_storage_repo.dart';

/// Always returns an over-band, unsafe rating to exercise the guard + fallback.
class _UnsafeProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => const StorySegment(
    storyText: 'Something far too intense for a toddler.',
    summary: 'too intense',
    rating: AgeRating.older, // exceeds a tiny child's band
  );
}

/// Always throws, to exercise the error path → fallback.
class _ThrowingProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async =>
      throw StateError('boom');
}

void main() {
  const child = ChildProfile(id: 'c1', displayName: 'Aiden', age: 3);
  const series = Series(
    id: 's1',
    childId: 'c1',
    title: 'Cloud Pirates',
    theme: StoryTheme.cozy,
    heroMode: HeroMode.childAsHero,
    seedSummary: 'A cozy sky adventure.',
  );

  late InMemoryStorageRepo repo;

  setUp(() async {
    repo = InMemoryStorageRepo();
    await repo.saveSeries(series);
  });

  test('takeTurn generates, vets, and persists a beat', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
      chosenTwist: 'gentle_surprise',
    );

    expect(beat.seq, 0);
    expect(beat.text, isNotEmpty);
    expect(beat.rating, AgeRating.tiny);

    final saved = await repo.loadBeats(series.id);
    expect(saved, hasLength(1));
  });

  test('consecutive turns increment seq and grow the story bible', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );

    final saved = await repo.loadBeats(series.id);
    expect(saved.map((b) => b.seq), [0, 1]);
    final updated = await repo.loadSeriesById(series.id);
    expect(updated!.storyBible, isNotEmpty);
  });

  test('unsafe output is rejected and falls back to a safe beat', () async {
    final engine = StoryEngine(
      ai: _UnsafeProvider(),
      repo: repo,
      maxRetries: 1,
    );
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    // Fallback is always within band.
    expect(beat.rating, AgeRating.tiny);
    expect(beat.text, isNot(contains('intense')));
    expect(await repo.loadBeats(series.id), hasLength(1));
  });

  test('provider errors fall back instead of breaking bedtime', () async {
    final engine = StoryEngine(ai: _ThrowingProvider(), repo: repo);
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );
    expect(beat.text, isNotEmpty);
    expect(beat.rating, AgeRating.tiny);
  });

  test('dice/option twists feed the learned profile', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.option,
      chosenTwist: 'mystery_door',
    );
    final learned = await repo.loadLearnedProfile(child.id);
    expect(learned?.twistAffinity['mystery_door'], 1);
  });
}
