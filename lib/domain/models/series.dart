/// A storyline. A child can have several running in parallel; "branching"
/// starts a new one (optionally forked from a beat). See `docs/data-model.md`.
class Series {
  const Series({
    required this.id,
    required this.childId,
    required this.title,
    required this.theme,
    this.customTheme,
    this.heroMode = HeroMode.surprise,
    this.heroName,
    this.bilingualEnabled = false,
    this.secondaryLanguage,
    this.bilingualBlend,
    this.seedSummary = '',
    this.status = SeriesStatus.active,
  });

  final String id;
  final String childId;
  final String title;

  /// The series' overall flavour, chosen at start.
  final StoryTheme theme;

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
  final SeriesStatus status;
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
