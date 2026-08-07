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
  });

  final String id;
  final String childId;

  /// The world's name, shown on the bookshelf (e.g. "Splat the Cat").
  final String name;

  /// A short description of the world used to keep every episode consistent.
  final String premise;

  /// Default flavour for episodes in this world.
  final StoryTheme theme;

  World copyWith({String? name, String? premise, StoryTheme? theme}) => World(
    id: id,
    childId: childId,
    name: name ?? this.name,
    premise: premise ?? this.premise,
    theme: theme ?? this.theme,
  );
}
