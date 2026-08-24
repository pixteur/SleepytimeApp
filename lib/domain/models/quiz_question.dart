/// A single onboarding question. This is a presentation/domain model — the
/// question bank lives in `QuizService`; answers are stored in [QuizResult].
/// Copy is English for now and will move to l10n in Phase 4. See `docs/i18n.md`.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    required this.dimension,
    this.choices = const [],
    this.seedsInterest = false,
    this.setsDetailLevel = false,
    this.isSoftSafetyHint = false,
  });

  final String id;
  final String prompt;
  final QuizAnswerType type;

  /// What this question is trying to learn. Several questions share a
  /// dimension and one is drawn at random, so two children are asked
  /// differently but tell us the same kinds of things.
  final QuizDimension dimension;

  /// Choices for [QuizAnswerType.choice] questions.
  final List<QuizChoice> choices;

  /// The labels, for a chooser that only needs the words.
  List<String> get options => [for (final c in choices) c.label];

  /// Answer should become an [Interest] (e.g. "something you love right now").
  final bool seedsInterest;

  /// Answer maps to the child's `detailLevel` (short / medium / long).
  final bool setsDetailLevel;

  /// A *soft* steer only — real banned themes are set in Settings, not here.
  /// See `docs/safety.md`.
  final bool isSoftSafetyHint;
}

/// One answer, and what picking it tells us.
///
/// [trait] is the part the story engine reads, so the wording of a question can
/// change — or a different question be drawn — without changing what a given
/// answer means.
class QuizChoice {
  const QuizChoice(this.label, this.trait);

  final String label;
  final String trait;
}

/// What a question is for. The seed is built per dimension, not per question,
/// which is what lets the bank be shuffled.
enum QuizDimension {
  /// How the child likes to engage with a problem.
  curiosity,

  /// Who they want beside them.
  company,

  /// What settles them — this one is about bedtime specifically.
  comfort,

  /// What they find funny.
  humour,

  /// How much excitement is enjoyable rather than too much.
  intensity,

  /// A real, current fascination, in their own words.
  fascination,

  /// Something to steer gently away from.
  avoid,

  /// How long a story should be.
  length,
}

enum QuizAnswerType { choice, freeText }
