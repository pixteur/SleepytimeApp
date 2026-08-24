import 'dart:math';

import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/child_profile.dart';
import 'models/interest.dart';
import 'models/quiz_question.dart';
import 'models/quiz_result.dart';
import 'quiz_bank.dart';

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

  /// A fresh draw of the quiz — one question per dimension. See `quiz_bank.dart`.
  static List<QuizQuestion> draw([Random? rng]) => drawQuiz(rng);

  /// Pure: distil answers into a story premise. Deterministic and unit-tested.
  ///
  /// Reads answers by **dimension**, not by question id, because which
  /// question was asked is a coin toss — "the locked box" and "find out how"
  /// are different questions about the same thing, and the premise should not
  /// depend on which one a child happened to be shown.
  static String deriveSeed(Map<String, String> answers, {String? parentBrief}) {
    /// What the child said for [dimension], as its trait, or null.
    String? traitFor(QuizDimension dimension) {
      for (final entry in answers.entries) {
        final question = questionById(entry.key);
        if (question == null || question.dimension != dimension) continue;
        final answer = entry.value.trim();
        if (answer.isEmpty) continue;
        for (final choice in question.choices) {
          if (choice.label.toLowerCase() == answer.toLowerCase()) {
            return choice.trait;
          }
        }
      }
      return null;
    }

    /// The child's own words for [dimension], or null.
    String? textFor(QuizDimension dimension) {
      for (final entry in answers.entries) {
        final question = questionById(entry.key);
        if (question?.dimension != dimension) continue;
        final answer = entry.value.trim();
        if (answer.isNotEmpty) return answer;
      }
      return null;
    }

    final sentences = <String>[];

    // What this child is like, in the order it matters for steering a story.
    final about = <String>[
      for (final dimension in [
        QuizDimension.curiosity,
        QuizDimension.company,
        QuizDimension.humour,
        QuizDimension.intensity,
      ])
        if (traitFor(dimension) != null) traitFor(dimension)!,
    ];
    sentences.add(
      about.isEmpty
          ? 'A gentle bedtime story.'
          : 'This child ${_joinWithAnd(about)}.',
    );

    final loves = textFor(QuizDimension.fascination);
    if (loves != null) sentences.add('Right now they are taken with $loves.');

    final comfort = traitFor(QuizDimension.comfort);
    if (comfort != null) {
      sentences.add('At the end of the day they are $comfort.');
    }

    final avoid = textFor(QuizDimension.avoid);
    if (avoid != null) sentences.add('Gently avoid: $avoid.');

    final brief = parentBrief?.trim();
    if (brief != null && brief.isNotEmpty) {
      sentences.add("Parent's note: $brief");
    }

    return sentences.join(' ');
  }

  /// "a, b and c" — the premise is read by a model, but it is also read by a
  /// parent in Settings, so it should be a sentence.
  static String _joinWithAnd(List<String> parts) {
    if (parts.length == 1) return parts.first;
    return '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
  }

  /// Map the length answer to a [DetailLevel].
  static DetailLevel detailLevelFor(Map<String, String> answers) {
    return switch (answers['length']?.toLowerCase()) {
      'short' => DetailLevel.short,
      'long' => DetailLevel.long,
      _ => DetailLevel.medium,
    };
  }

  /// Every question in the bank that seeds an interest.
  static Iterable<QuizQuestion> get _interestQuestions sync* {
    for (final questions in quizBank.values) {
      for (final q in questions) {
        if (q.seedsInterest) yield q;
      }
    }
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
    for (final q in _interestQuestions) {
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
