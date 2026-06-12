import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/domain/models/series.dart';
import 'package:sleepytime/domain/series_service.dart';
import 'package:sleepytime/domain/twist_deck.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  group('SeriesService', () {
    late InMemoryStorageRepo repo;
    late SeriesService service;

    setUp(() {
      repo = InMemoryStorageRepo();
      service = SeriesService(repo);
    });

    test('create persists and lists only active series', () async {
      final s = await service.create(
        childId: 'c1',
        title: 'Cloud Pirates',
        theme: StoryTheme.adventure,
        heroMode: HeroMode.childAsHero,
      );
      expect(s.id, isNotEmpty);
      expect(await service.forChild('c1'), hasLength(1));

      await service.archive(s);
      expect(await service.forChild('c1'), isEmpty);
      expect(await service.archived('c1'), hasLength(1));
    });

    test('branch copies flavour and records the fork point', () async {
      final base = await service.create(
        childId: 'c1',
        title: 'Cloud Pirates',
        theme: StoryTheme.adventure,
        heroName: 'Captain Bramble',
        heroMode: HeroMode.namedHero,
        seedSummary: 'A sky saga.',
      );
      final branched = await service.branch(
        from: base,
        title: 'Cloud Pirates: Side Quest',
        fromBeatId: 'beat-42',
      );
      expect(branched.theme, StoryTheme.adventure);
      expect(branched.heroName, 'Captain Bramble');
      expect(branched.branchedFromBeatId, 'beat-42');
      expect(await service.forChild('c1'), hasLength(2));
    });
  });

  group('TwistDeck', () {
    const deck = TwistDeck();

    test('offers six option cards', () {
      expect(deck.options(), hasLength(6));
    });

    test('roll is deterministic with a seeded Random', () {
      final t1 = deck.roll(Random(1));
      final t2 = deck.roll(Random(1));
      expect(t1.id, t2.id);
    });

    test('byId finds a known twist', () {
      expect(deck.byId('mystery_door')?.label, isNotNull);
      expect(deck.byId('nope'), isNull);
    });
  });
}
