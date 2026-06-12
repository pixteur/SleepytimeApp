import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/child_profile.dart';
import 'models/interest.dart';
import 'models/quiz_question.dart';
import 'models/quiz_result.dart';

/// Outcome of submitting a quiz: the saved [result] plus derived effects the
/// caller applies to the profile (detail level) — interests are persisted here.
class QuizOutcome {
  const QuizOutcome({
    required this.result,
    required this.detailLevel,
    required this.seededInterests,
  });

  final QuizResult result;
  final DetailLevel detailLevel;
  final List<Interest> seededInterests;
}

/// Owns the onboarding question bank, the pure seed-derivation, and quiz
/// submission. Copy is English for now (l10n in Phase 4). See `docs/i18n.md`,
/// `build-plan/phase-1-profiles-quiz.md`.
class QuizService {
  QuizService(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final Uuid _uuid;

  /// The full first-run quiz. Stable ids are referenced by [deriveSeed].
  static const List<QuizQuestion> fullQuiz = [
    QuizQuestion(
      id: 'creature',
      prompt: 'What kind of creature do you like best?',
      type: QuizAnswerType.choice,
      options: ['Dragon', 'Puppy', 'Robot', 'Something else'],
    ),
    QuizQuestion(
      id: 'realVsMagical',
      prompt: 'Real-world adventures or magical ones?',
      type: QuizAnswerType.choice,
      options: ['Real-world', 'Magical'],
    ),
    QuizQuestion(
      id: 'funnyVsExciting',
      prompt: 'Funny stories or exciting ones?',
      type: QuizAnswerType.choice,
      options: ['Funny', 'Exciting'],
    ),
    QuizQuestion(
      id: 'lovedStories',
      prompt: 'Are there stories, books, or shows you already love?',
      type: QuizAnswerType.freeText,
      seedsInterest: true,
    ),
    QuizQuestion(
      id: 'favoriteCharacter',
      prompt: 'Do you have a favourite character?',
      type: QuizAnswerType.freeText,
      seedsInterest: true,
    ),
    QuizQuestion(
      id: 'place',
      prompt: 'Where should the stories happen?',
      type: QuizAnswerType.choice,
      options: ['Space', 'Ocean', 'Forest', 'Castle', 'City'],
    ),
    QuizQuestion(
      id: 'companion',
      prompt: 'Who comes along on the adventure?',
      type: QuizAnswerType.choice,
      options: ['An animal sidekick', 'A robot', 'A fairy', 'No-one'],
    ),
    QuizQuestion(
      id: 'mood',
      prompt: 'Bright daytime stories or cozy night-time ones?',
      type: QuizAnswerType.choice,
      options: ['Bright', 'Cozy'],
    ),
    QuizQuestion(
      id: 'loves',
      prompt: 'What is something you love right now?',
      type: QuizAnswerType.freeText,
      seedsInterest: true,
    ),
    QuizQuestion(
      id: 'length',
      prompt: 'How long should stories be?',
      type: QuizAnswerType.choice,
      options: ['Short', 'Medium', 'Long'],
      setsDetailLevel: true,
    ),
    QuizQuestion(
      id: 'avoid',
      prompt: "Anything a little scary you'd rather NOT hear about?",
      type: QuizAnswerType.freeText,
      isSoftSafetyHint: true,
    ),
  ];

  /// Pure: distil answers (+ optional parent brief) into a story premise.
  /// Deterministic and unit-tested — no I/O. See tests.
  static String deriveSeed(Map<String, String> answers, {String? parentBrief}) {
    String? a(String id) {
      final v = answers[id]?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final sentences = <String>[];

    final tone = a('funnyVsExciting')?.toLowerCase();
    final realm = a('realVsMagical')?.toLowerCase();
    final realmPhrase = switch (realm) {
      'magical' => 'a magical',
      'real-world' => 'a real-world',
      _ => 'a',
    };
    var opener = 'A ${tone ?? 'gentle'} bedtime story in $realmPhrase world';
    final creature = a('creature');
    if (creature != null && creature.toLowerCase() != 'something else') {
      opener += ', featuring a ${creature.toLowerCase()}';
    }
    final place = a('place');
    if (place != null) opener += ', set in the ${place.toLowerCase()}';
    final companion = a('companion');
    if (companion != null && companion.toLowerCase() != 'no-one') {
      opener += ', with ${companion.toLowerCase()} along for the ride';
    }
    sentences.add('$opener.');

    final loves = <String>[
      for (final id in ['lovedStories', 'favoriteCharacter', 'loves'])
        if (a(id) != null) a(id)!,
    ];
    if (loves.isNotEmpty) {
      sentences.add('The child currently loves ${loves.join(', ')}.');
    }

    final mood = a('mood')?.toLowerCase();
    if (mood != null) sentences.add('Keep the mood $mood.');

    final avoid = a('avoid');
    if (avoid != null) sentences.add('Gently avoid: $avoid.');

    final brief = parentBrief?.trim();
    if (brief != null && brief.isNotEmpty) {
      sentences.add("Parent's note: $brief");
    }

    return sentences.join(' ');
  }

  /// Map the length answer to a [DetailLevel].
  static DetailLevel detailLevelFor(Map<String, String> answers) {
    return switch (answers['length']?.toLowerCase()) {
      'short' => DetailLevel.short,
      'long' => DetailLevel.long,
      _ => DetailLevel.medium,
    };
  }

  /// Persist a quiz result and any seeded interests; return derived effects.
  Future<QuizOutcome> submit({
    required String childId,
    required Map<String, String> answers,
    QuizKind kind = QuizKind.full,
    String? parentBrief,
  }) async {
    final seed = deriveSeed(answers, parentBrief: parentBrief);
    final result = QuizResult(
      id: _uuid.v4(),
      childId: childId,
      kind: kind,
      answers: answers,
      seedSummary: seed,
    );
    await _repo.saveQuizResult(result);

    final seeded = <Interest>[];
    for (final q in fullQuiz.where((q) => q.seedsInterest)) {
      final value = answers[q.id]?.trim();
      if (value == null || value.isEmpty) continue;
      final interest = Interest(
        id: _uuid.v4(),
        childId: childId,
        label: value,
        source: InterestSource.quiz,
      );
      await _repo.saveInterest(interest);
      seeded.add(interest);
    }

    return QuizOutcome(
      result: result,
      detailLevel: detailLevelFor(answers),
      seededInterests: seeded,
    );
  }
}
