import 'narration.dart';

/// One saved episode — the unit of story memory. Belongs to a series and is
/// structured so a saga stays coherent for weeks. See `docs/data-model.md`.
class Beat {
  const Beat({
    required this.id,
    required this.seriesId,
    required this.childId,
    required this.seq,
    required this.intent,
    required this.text,
    required this.summary,
    this.title = '',
    this.rating = AgeRating.little,
    this.setting = '',
    this.chosenTwist,
    this.characters = const [],
    this.openThreads = const [],
    this.language = 'en',
    this.isFinal = false,
    this.narration = const NarrationNotes(),
  });

  final String id;
  final String seriesId;
  final String childId;

  /// Order within the series.
  final int seq;
  final StoryIntent intent;

  /// The full episode text, as shown and read aloud.
  final String text;

  /// Short recap — powers both the context window and the archive list.
  final String summary;

  /// This chapter's own title, shown next to the chapter number while reading.
  /// Empty for chapters written before titles existed, and for fallback
  /// chapters — callers must cope with a blank.
  final String title;
  final AgeRating rating;
  final String setting;
  final String? chosenTwist;

  /// Recurring cast (Phase 2 enriches with per-character voice hints).
  final List<String> characters;

  /// Unresolved hooks to (maybe) pay off later.
  final List<String> openThreads;
  final String language;

  /// True when this is the last chapter of the story (a complete ending).
  final bool isFinal;

  /// How this chapter should be read aloud. Empty for chapters written before
  /// cues existed, and for fallback chapters — the reader speaks plainly then.
  final NarrationNotes narration;
}

/// How tonight's episode began. See `docs/00-overview.md`.
enum StoryIntent { dice, option, continued, request }

/// Self-reported + guard-validated rating; mirrors the age bands. See `docs/safety.md`.
enum AgeRating { tiny, little, big, older }
