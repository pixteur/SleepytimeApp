/// A storyline. A child can have several running in parallel; "branching"
/// starts a new one (optionally forked from a beat). See `docs/data-model.md`.
class Series {
  const Series({
    required this.id,
    required this.childId,
    required this.title,
    required this.theme,
    this.extraThemes = const [],
    this.autoTitle = false,
    this.worldId,
    this.customTheme,
    this.heroMode = HeroMode.surprise,
    this.heroName,
    this.bilingualEnabled = false,
    this.secondaryLanguage,
    this.bilingualBlend,
    this.seedSummary = '',
    this.storyBible = '',
    this.branchedFromBeatId,
    this.status = SeriesStatus.active,
  });

  final String id;
  final String childId;
  final String title;

  /// The World (universe) this episode belongs to, or null for a standalone
  /// story. Episodes in the same world share characters + premise.
  final String? worldId;

  /// The series' overall flavour, chosen at start.
  final StoryTheme theme;

  /// Up to two further flavours blended with [theme] (the chooser allows three
  /// picks in total). Empty for a single-theme story.
  final List<StoryTheme> extraThemes;

  /// True while [title] is a placeholder waiting to be replaced by a title the
  /// model derives from the first chapter. Cleared once named.
  final bool autoTitle;

  /// [theme] plus [extraThemes], in the order they were picked.
  List<StoryTheme> get allThemes => [theme, ...extraThemes];

  /// Free-text flavour when [theme] is [StoryTheme.custom].
  final String? customTheme;

  final HeroMode heroMode;
  final String? heroName;

  /// Bilingual mode is a modifier, independent of [theme] — any story can use it.
  final bool bilingualEnabled;
  final String? secondaryLanguage;
  final BilingualBlend? bilingualBlend;

  /// Premise this series starts from (distilled from the quiz + briefs).
  final String seedSummary;

  /// Rolling summary the engine maintains for cheap long-term continuity.
  final String storyBible;

  /// If this series was forked from a beat in another series.
  final String? branchedFromBeatId;

  final SeriesStatus status;

  Series copyWith({
    String? title,
    bool? autoTitle,
    String? seedSummary,
    String? storyBible,
    SeriesStatus? status,
  }) {
    return Series(
      id: id,
      childId: childId,
      title: title ?? this.title,
      theme: theme,
      extraThemes: extraThemes,
      autoTitle: autoTitle ?? this.autoTitle,
      worldId: worldId,
      customTheme: customTheme,
      heroMode: heroMode,
      heroName: heroName,
      bilingualEnabled: bilingualEnabled,
      secondaryLanguage: secondaryLanguage,
      bilingualBlend: bilingualBlend,
      seedSummary: seedSummary ?? this.seedSummary,
      storyBible: storyBible ?? this.storyBible,
      branchedFromBeatId: branchedFromBeatId,
      status: status ?? this.status,
    );
  }
}

/// The ~16 series themes surfaced in the chooser. See `docs/ui-ux.md`.
enum StoryTheme {
  adventure,
  technical,
  nature,
  documentary,
  learning,
  cozy,
  feelings,
  mystery,
  silly,
  fairytale,
  history,
  aroundTheWorld,
  superhero,
  mindfulness,
  sliceOfLife,
  surprise,
  custom,
}

/// Who the hero is — chosen when a series begins.
enum HeroMode { childAsHero, namedHero, surprise }

/// How much of the second language to weave in (bilingual mode).
enum BilingualBlend { sprinkle, phrases, alternating }

enum SeriesStatus { active, archived }
