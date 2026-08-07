import 'cast_changes.dart';
import 'series.dart';

/// A story "universe" — a reusable world (e.g. "Splat the Cat") that holds a
/// premise + a cast of [Character]s and spawns many different episodes (each an
/// episode = a [Series]). See `docs/data-model.md`.
class World {
  const World({
    required this.id,
    required this.childId,
    required this.name,
    this.premise = '',
    this.theme = StoryTheme.cozy,
    this.extraThemes = const [],
    this.pendingCastChanges = CastChanges.none,
  });

  final String id;
  final String childId;

  /// The world's name, shown on the bookshelf (e.g. "Splat the Cat").
  final String name;

  /// A short description of the world used to keep every episode consistent.
  final String premise;

  /// Default flavour for episodes in this world.
  final StoryTheme theme;

  /// Up to two further flavours blended with [theme] in every episode. Editing
  /// these changes how future episodes are written.
  final List<StoryTheme> extraThemes;

  /// [theme] plus [extraThemes], in the order they were picked.
  List<StoryTheme> get allThemes => [theme, ...extraThemes];

  /// Cast edits the next story still has to acknowledge (arrivals to introduce,
  /// departures to write out gently). Cleared once a chapter has used them.
  final CastChanges pendingCastChanges;

  World copyWith({
    String? name,
    String? premise,
    StoryTheme? theme,
    List<StoryTheme>? extraThemes,
    CastChanges? pendingCastChanges,
  }) => World(
    id: id,
    childId: childId,
    name: name ?? this.name,
    premise: premise ?? this.premise,
    theme: theme ?? this.theme,
    extraThemes: extraThemes ?? this.extraThemes,
    pendingCastChanges: pendingCastChanges ?? this.pendingCastChanges,
  );
}
