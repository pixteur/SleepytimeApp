/// A living model of a child that grows from play — so stories keep improving
/// without re-quizzing. Phase 1 scaffolds it; the story engine populates it
/// from Phase 2 on (twist picks, favourites, inferred interests).
/// See `docs/data-model.md`.
class LearnedProfile {
  const LearnedProfile({
    required this.childId,
    this.twistAffinity = const {},
    this.favorites = const [],
    this.inferredInterests = const [],
    this.observedTone = '',
  });

  final String childId;

  /// twist tag → how often the kid has chosen it.
  final Map<String, int> twistAffinity;

  /// Replayed / thumbed-up beat or series ids.
  final List<String> favorites;

  /// Topics the kid keeps steering toward (candidate Interests).
  final List<String> inferredInterests;

  /// Observed preference, e.g. "funnier, shorter stories".
  final String observedTone;

  LearnedProfile copyWith({
    Map<String, int>? twistAffinity,
    List<String>? favorites,
    List<String>? inferredInterests,
    String? observedTone,
  }) {
    return LearnedProfile(
      childId: childId,
      twistAffinity: twistAffinity ?? this.twistAffinity,
      favorites: favorites ?? this.favorites,
      inferredInterests: inferredInterests ?? this.inferredInterests,
      observedTone: observedTone ?? this.observedTone,
    );
  }
}
