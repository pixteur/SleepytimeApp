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

/// Always returns a safe, non-final segment — never wants to end the story.
class _NeverEndsProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => const StorySegment(
    storyText: 'The journey continued on and on.',
    summary: 'still going',
    rating: AgeRating.tiny,
    openThreads: ['what next?'],
  );
}

/// Returns a safe segment marked as the final chapter.
class _FinalProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => const StorySegment(
    storyText: 'And so, warm and sleepy, everyone drifted off. The end.',
    summary: 'A peaceful ending.',
    rating: AgeRating.tiny,
    isFinal: true,
  );
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
    // The reason is exposed so the UI can warn instead of silently going generic.
    expect(engine.lastFallbackReason, contains('boom'));
  });

  test('lastFallbackReason is cleared after a successful turn', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    expect(engine.lastFallbackReason, isNull);
  });

  test('concurrent turns are serialized — no duplicate seq', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    // Fire two turns at once (e.g. background auto-complete + a user tap).
    final results = await Future.wait([
      engine.takeTurn(child: child, series: series, intent: StoryIntent.dice),
      engine.takeTurn(
        child: child,
        series: series,
        intent: StoryIntent.continued,
      ),
    ]);
    expect((results.map((b) => b.seq).toList()..sort()), [0, 1]);
    final saved = await repo.loadBeats(series.id);
    expect(saved.map((b) => b.seq).toList(), [0, 1]); // no duplicate
  });

  test('persists the final-chapter flag from the segment', () async {
    final engine = StoryEngine(ai: _FinalProvider(), repo: repo);
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );
    expect(beat.isFinal, isTrue);
    final saved = await repo.loadBeats(series.id);
    expect(saved.last.isFinal, isTrue);
  });

  test(
    'the chapter cap forces a final chapter even if the model won\'t',
    () async {
      final engine = StoryEngine(
        ai: _NeverEndsProvider(),
        repo: repo,
        maxChapters: 3,
      );
      Beat last = await engine.takeTurn(
        child: child,
        series: series,
        intent: StoryIntent.dice,
      );
      for (var i = 0; i < 5 && !last.isFinal; i++) {
        last = await engine.takeTurn(
          child: child,
          series: series,
          intent: StoryIntent.continued,
        );
      }
      expect(last.isFinal, isTrue);
      expect(last.seq, 2); // 0-based: the 3rd chapter is forced final
      expect(last.openThreads, isEmpty); // no dangling hook on the last chapter
    },
  );

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
