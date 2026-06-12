import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/domain/models/child_profile.dart';
import 'package:sleepytime/domain/models/interest.dart';
import 'package:sleepytime/domain/quiz_service.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  group('deriveSeed (pure)', () {
    test('builds a premise from common answers', () {
      final seed = QuizService.deriveSeed({
        'funnyVsExciting': 'Exciting',
        'realVsMagical': 'Magical',
        'creature': 'Dragon',
        'place': 'Forest',
        'companion': 'A fairy',
        'mood': 'Cozy',
        'loves': 'Jupiter',
      });
      expect(seed, contains('exciting'));
      expect(seed, contains('magical world'));
      expect(seed, contains('dragon'));
      expect(seed, contains('forest'));
      expect(seed, contains('Jupiter'));
      expect(seed, contains('cozy'));
    });

    test('is graceful when answers are sparse', () {
      final seed = QuizService.deriveSeed(const {});
      expect(seed, isNotEmpty);
      expect(seed, contains('bedtime story'));
    });

    test('omits "no-one" companion and weaves in the parent brief', () {
      final seed = QuizService.deriveSeed({
        'companion': 'No-one',
      }, parentBrief: 'family matters');
      expect(seed.toLowerCase(), isNot(contains('along for the ride')));
      expect(seed, contains('family matters'));
    });
  });

  group('detailLevelFor', () {
    test('maps the length answer', () {
      expect(
        QuizService.detailLevelFor({'length': 'Short'}),
        DetailLevel.short,
      );
      expect(QuizService.detailLevelFor({'length': 'Long'}), DetailLevel.long);
      expect(QuizService.detailLevelFor(const {}), DetailLevel.medium);
    });
  });

  group('submit', () {
    test(
      'persists the result and seeds interests from flagged answers',
      () async {
        final repo = InMemoryStorageRepo();
        final service = QuizService(repo);

        final outcome = await service.submit(
          childId: 'c1',
          answers: {
            'loves': 'fractals',
            'lovedStories': 'The Gruffalo',
            'length': 'Long',
          },
        );

        expect(outcome.detailLevel, DetailLevel.long);
        expect(await repo.latestQuizResult('c1'), isNotNull);

        final interests = await repo.loadInterests('c1');
        final labels = interests.map((i) => i.label).toSet();
        expect(labels, containsAll(['fractals', 'The Gruffalo']));
        expect(interests.every((i) => i.source == InterestSource.quiz), isTrue);
      },
    );
  });
}
