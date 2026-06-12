/// A single onboarding question. This is a presentation/domain model — the
/// question bank lives in `QuizService`; answers are stored in [QuizResult].
/// Copy is English for now and will move to l10n in Phase 4. See `docs/i18n.md`.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    this.options = const [],
    this.seedsInterest = false,
    this.setsDetailLevel = false,
    this.isSoftSafetyHint = false,
  });

  final String id;
  final String prompt;
  final QuizAnswerType type;

  /// Choices for [QuizAnswerType.choice] questions.
  final List<String> options;

  /// Answer should become an [Interest] (e.g. "something you love right now").
  final bool seedsInterest;

  /// Answer maps to the child's `detailLevel` (short / medium / long).
  final bool setsDetailLevel;

  /// A *soft* steer only — real banned themes are set in Settings, not here.
  /// See `docs/safety.md`.
  final bool isSoftSafetyHint;
}

enum QuizAnswerType { choice, freeText }
