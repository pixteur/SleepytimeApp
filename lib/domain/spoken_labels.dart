/// What the storyteller says out loud when a child is *navigating* rather than
/// listening — the pack's name on the cover, and each chapter's name as the
/// wheel passes over it.
///
/// Pure naming rules, kept apart from `SleepyService` so the read-only probes
/// in `tool/` can produce byte-identical labels under plain `dart run`. The
/// service imports a voice provider, and through it all of Flutter; a tool that
/// spoke a *slightly* different label would look up a cache key that exists
/// and get silence on the device.
library;

import 'models/beat.dart';
import 'models/series.dart';

/// What the device says when a child lands on the pack. Short on purpose: the
/// wheel is how they browse, so this has to be over before they have moved on.
String spokenTitleFor(Series series) => series.title.trim();

/// What one chapter says as the wheel passes over it. The number carries the
/// navigation and the title tells them which one it is — in the story's own
/// language, since that is what the voice is speaking.
String spokenChapterFor(Beat beat, String language) {
  final word = _chapterWord(language);
  final title = beat.title.trim();
  return title.isEmpty
      ? '$word ${beat.seq + 1}'
      : '$word ${beat.seq + 1}. $title';
}

String _chapterWord(String language) =>
    switch (language.toLowerCase().split('-').first) {
      'fr' => 'Chapitre',
      'es' => 'Capítulo',
      'de' => 'Kapitel',
      'it' => 'Capitolo',
      'pt' => 'Capítulo',
      _ => 'Chapter',
    };
