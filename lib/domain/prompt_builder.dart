import 'age_policy.dart';
import 'models/beat.dart';
import 'models/child_profile.dart';
import 'models/series.dart';
import 'models/story_request.dart';

/// The assembled prompt handed to an `AiProvider`. The provider only translates
/// this into its wire format (and asks for the structured fields).
class StoryPrompt {
  const StoryPrompt({required this.system, required this.user});

  final String system;
  final String user;
}

/// Turns a [StoryRequest] into a [StoryPrompt]. The ONE place that decides how
/// we prompt — pure and golden-tested. See `docs/architecture.md`, `docs/safety.md`.
class PromptBuilder {
  const PromptBuilder();

  StoryPrompt build(
    StoryRequest req, {
    List<String> bannedThemes = BannedThemes.defaults,
  }) {
    final band = req.child.ageBand;

    final system = StringBuffer()
      ..writeln('You are a warm, imaginative bedtime storyteller for children.')
      ..writeln(AgePolicy.policyFor(band))
      ..writeln('Universal rules:')
      ..writeAll(AgePolicy.universalRules.map((r) => '- $r'), '\n')
      ..writeln()
      ..writeln(
        'Banned themes — never include, even in passing: '
        '${bannedThemes.join(', ')}.',
      )
      ..writeln(_themeGuidance(req.series))
      ..writeln('Write the story in ${_languageName(req.child.language)}.')
      ..writeln(
        'Target length per chapter: ${_lengthFor(req.child.detailLevel)}.',
      )
      ..writeln(
        req.mustConclude
            ? 'This is chapter ${req.chapterNumber} and the FINAL chapter of the '
                  'story. Bring everything to a warm, satisfying close now, tie '
                  'off the open threads, end peacefully and ready for sleep, and '
                  'set "is_final" to true.'
            : 'Tell ONE complete bedtime story across about 3–${req.maxChapters} '
                  'short chapters. This is chapter ${req.chapterNumber}. Each '
                  'chapter should end on a gentle, calm note. When the story '
                  'reaches a warm, satisfying resolution, set "is_final" to true; '
                  'otherwise leave a soft hook for the next chapter and set '
                  '"is_final" to false. Always end the FINAL chapter peacefully, '
                  'ready for sleep.',
      )
      ..writeln(
        'The audience band is "${band.name}". Write strictly within it and set '
        '"rating" to "${band.name}" (never higher).',
      )
      ..writeln(
        'Return: this chapter\'s text, a one-line summary, the rating, the '
        'setting, recurring characters, any open story threads, and is_final '
        '(true on the last chapter).',
      )
      ..writeln(
        'Also return "story_title": a short, warm title for the WHOLE story '
        '(2–6 words, no quotes, no subtitle) drawn from what actually happens '
        'in it — the kind of title a child would recognise on a book spine. '
        'Keep it the same in later chapters of the same story.',
      );

    final user = StringBuffer();
    if (req.series.autoTitle) {
      user.writeln(
        'This story has no title yet — invent one in "story_title" from what '
        'happens in it.',
      );
    } else {
      user.writeln('Series: "${req.series.title}".');
    }
    user.writeln('Premise: ${req.series.seedSummary}');

    if (req.worldPremise.trim().isNotEmpty) {
      user.writeln(
        'This is a new episode in an ongoing world: ${req.worldPremise.trim()}. '
        'Keep the world, tone, and characters consistent, but tell a fresh, '
        'self-contained adventure.',
      );
    }
    if (req.cast.isNotEmpty) {
      user.writeln('Recurring characters (keep them recognisable):');
      for (final c in req.cast) {
        user.writeln('- $c');
      }
    }

    _writeCastChanges(user, req);

    if (req.series.storyBible.trim().isNotEmpty) {
      user.writeln('Story so far: ${req.series.storyBible}');
    }

    final loves = req.interests
        .where((i) => i.active)
        .map((i) => i.label)
        .toList();
    if (loves.isNotEmpty) {
      user.writeln('The child currently loves: ${loves.join(', ')}.');
    }

    if (req.recentBeats.isNotEmpty) {
      user.writeln('Recent chapters:');
      for (final b in req.recentBeats) {
        user.writeln('- ${b.summary}');
      }
    }

    user.writeln(_intentLine(req));

    if (req.series.bilingualEnabled && req.series.secondaryLanguage != null) {
      final blend = req.series.bilingualBlend?.name ?? 'phrases';
      user.writeln(
        'Bilingual mode: naturally weave in '
        '${_languageName(req.series.secondaryLanguage!)} at a "$blend" level, '
        'keeping meaning recoverable from context, and tag which spans are in '
        'which language.',
      );
    }

    return StoryPrompt(
      system: system.toString().trim(),
      user: user.toString().trim(),
    );
  }

  /// Arrivals and departures the grown-up made in the world's cast since the
  /// last story. A removed character must be *written out*, warmly and on the
  /// page — never silently dropped, and never in a way that upsets a child at
  /// bedtime. See `docs/safety.md`.
  void _writeCastChanges(StringBuffer user, StoryRequest req) {
    final changes = req.castChanges;
    if (changes.isEmpty) return;

    if (changes.joined.isNotEmpty) {
      user.writeln(
        'New to this world — introduce them naturally in this chapter with a '
        'warm first meeting, then treat them as part of the group:',
      );
      for (final c in changes.joined) {
        user.writeln('- $c');
      }
    }
    if (changes.left.isNotEmpty) {
      user.writeln(
        'Leaving the story — give each of them a proper send-off in this '
        'chapter, then never mention them again in later chapters:',
      );
      for (final c in changes.left) {
        user.writeln('- $c');
      }
      user.writeln(
        'Make the farewell gentle, hopeful, and interesting: they set off on '
        'an adventure of their own, are called home, sail away to somewhere '
        'wonderful, or go where they are needed. Let the others say a proper '
        'goodbye and feel glad for them. Absolutely never use illness, death, '
        'danger, punishment, an argument, or an unexplained disappearance, and '
        'never make it frightening or sad. Leave the door open for a happy '
        'letter or visit someday.',
      );
    }
  }

  String _intentLine(StoryRequest req) {
    final twist = req.chosenTwist;
    return switch (req.intent) {
      StoryIntent.continued =>
        'Continue the story naturally from where it left off.',
      StoryIntent.dice when twist != null =>
        'Begin a fresh twist for tonight: $twist',
      StoryIntent.option when twist != null => 'Tonight\'s direction: $twist',
      StoryIntent.request when twist != null =>
        'The child asked for a story about: «$twist». Honour the spirit of '
            'this within all the safety rules above.',
      _ => 'Start a gentle new chapter for tonight.',
    };
  }

  String _themeGuidance(Series s) {
    if (s.theme == StoryTheme.custom && (s.customTheme?.isNotEmpty ?? false)) {
      return 'Series flavour (custom): ${s.customTheme}.';
    }
    final phrases = s.allThemes.map(_themePhrase).toList();
    if (phrases.length == 1) {
      return 'Series flavour: lean into ${phrases.single}.';
    }
    return 'Series flavour: blend these into one story — '
        '${phrases.join('; ')}. Lead with the first and let the others colour '
        'it, rather than telling separate stories.';
  }

  String _themePhrase(StoryTheme theme) {
    return switch (theme) {
      StoryTheme.adventure =>
        'quests, exploration, and brave-but-cozy excitement',
      StoryTheme.technical =>
        'how things work — machines, building, simple engineering ideas',
      StoryTheme.nature =>
        'animals, ecosystems, the outdoors, and gentle wonder',
      StoryTheme.documentary =>
        'a friendly narrator explaining real, accurate facts',
      StoryTheme.learning => 'teaching a small concept through the story',
      StoryTheme.cozy => 'slow, soft, sleepy, low-stakes comfort',
      StoryTheme.feelings => 'empathy, big feelings, kindness, and sharing',
      StoryTheme.mystery =>
        'gentle, age-appropriate puzzle-solving (never scary)',
      StoryTheme.silly => 'pure comedy, wordplay, and giggles',
      StoryTheme.fairytale => 'classic "once upon a time" storybook cadence',
      StoryTheme.history => 'a friendly visit to the past',
      StoryTheme.aroundTheWorld =>
        'cultures, geography, and food around the world',
      StoryTheme.superhero =>
        'everyday-hero acts of helping and courage (not combat)',
      StoryTheme.mindfulness => 'breathing, gratitude, and calm imagery',
      StoryTheme.sliceOfLife => 'warm everyday moments and gentle routines',
      StoryTheme.surprise =>
        'any delightful, age-appropriate flavour you choose',
      StoryTheme.custom => 'a delightful, age-appropriate flavour',
    };
  }

  String _lengthFor(DetailLevel level) => switch (level) {
    DetailLevel.short => 'a short bedtime tale (about 150–250 words)',
    DetailLevel.medium => 'a medium story (about 300–450 words)',
    DetailLevel.long => 'a longer chapter (about 500–700 words)',
  };

  String _languageName(String code) => switch (code) {
    'en' => 'English',
    'fr' => 'French',
    'es' => 'Spanish',
    'ja' => 'Japanese',
    _ => code,
  };
}
