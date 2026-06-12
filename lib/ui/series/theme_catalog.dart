import '../../domain/models/series.dart';

/// Kid-facing label + emoji for each story theme, used by the chooser and
/// library cards. Grouped per `docs/ui-ux.md`. Copy moves to l10n in Phase 4.
class ThemeMeta {
  const ThemeMeta(this.theme, this.emoji, this.label);

  final StoryTheme theme;
  final String emoji;
  final String label;
}

/// Theme groups for the chooser (avoids an overwhelming flat grid).
const Map<String, List<ThemeMeta>> themeGroups = {
  '🚀 Exciting': [
    ThemeMeta(StoryTheme.adventure, '🗺️', 'Adventure'),
    ThemeMeta(StoryTheme.mystery, '🔍', 'Mystery'),
    ThemeMeta(StoryTheme.superhero, '🦸', 'Superhero'),
  ],
  '🌙 Calm & Bedtime': [
    ThemeMeta(StoryTheme.cozy, '🌙', 'Cozy / Dreamtime'),
    ThemeMeta(StoryTheme.mindfulness, '🧘', 'Mindfulness'),
    ThemeMeta(StoryTheme.feelings, '💛', 'Feelings & Kindness'),
    ThemeMeta(StoryTheme.sliceOfLife, '🏡', 'Slice-of-Life'),
  ],
  '🔬 Discover & Learn': [
    ThemeMeta(StoryTheme.nature, '🌿', 'Nature'),
    ThemeMeta(StoryTheme.technical, '⚙️', 'Technical'),
    ThemeMeta(StoryTheme.documentary, '🎬', 'Documentary'),
    ThemeMeta(StoryTheme.learning, '📚', 'Learning'),
    ThemeMeta(StoryTheme.history, '⏳', 'History'),
    ThemeMeta(StoryTheme.aroundTheWorld, '🌍', 'Around the World'),
  ],
  '✨ Imagine & Giggle': [
    ThemeMeta(StoryTheme.fairytale, '🏰', 'Fairytale'),
    ThemeMeta(StoryTheme.silly, '😄', 'Silly / Giggles'),
  ],
  '🎲 Anything': [
    ThemeMeta(StoryTheme.surprise, '🎲', 'Surprise'),
    ThemeMeta(StoryTheme.custom, '✏️', 'Custom'),
  ],
};

/// Flattened lookup of every theme's metadata.
final Map<StoryTheme, ThemeMeta> themeMetaByTheme = {
  for (final group in themeGroups.values)
    for (final meta in group) meta.theme: meta,
};

ThemeMeta metaFor(StoryTheme theme) =>
    themeMetaByTheme[theme] ??
    const ThemeMeta(StoryTheme.custom, '✏️', 'Custom');
