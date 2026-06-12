/// Stored answers from an onboarding quiz — the raw material the engine
/// distills into a series seed. Versioned and re-takeable as the kid grows.
/// See `docs/data-model.md`.
class QuizResult {
  const QuizResult({
    required this.id,
    required this.childId,
    required this.kind,
    required this.answers,
    required this.seedSummary,
    this.version = 1,
  });

  final String id;
  final String childId;
  final QuizKind kind;

  /// questionId → answer (chosen option label or free text).
  final Map<String, String> answers;

  /// Distilled premise derived from [answers] (+ the parent brief).
  final String seedSummary;
  final int version;
}

/// Which flavour of quiz produced this result. See `docs/data-model.md`.
///
/// - [full]    first-run onboarding
/// - [mini]    short "what kind of story this time?" when starting a new series
/// - [checkin] a single refining question asked occasionally
enum QuizKind { full, mini, checkin }
