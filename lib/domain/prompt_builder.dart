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
      ..writeln('Target length: ${_lengthFor(req.child.detailLevel)}.')
      ..writeln(
        'Return: the next chapter (ending calm and safe), a one-line summary, '
        'an age rating (one of tiny/little/big/older), the setting, recurring '
        'characters, and any open story threads.',
      );

    final user = StringBuffer()
      ..writeln('Series: "${req.series.title}".')
      ..writeln('Premise: ${req.series.seedSummary}');

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
    final phrase = switch (s.theme) {
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
    return 'Series flavour: lean into $phrase.';
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
