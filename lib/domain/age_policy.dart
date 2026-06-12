import 'models/beat.dart';
import 'models/child_profile.dart';

/// Age-band safety policies (injected verbatim into every system prompt),
/// universal rules, and the default banned-themes list. The single source of
/// truth that both `PromptBuilder` and `SafetyGuard` rely on. See `docs/safety.md`.
class AgePolicy {
  const AgePolicy._();

  static const List<String> universalRules = [
    'Always end gently and reassuringly — this is a bedtime story.',
    'Kindness, courage, and curiosity win the day.',
    'Never include anything a child could dangerously imitate.',
    'No graphic violence, gore, sexual content, romance, or substances.',
  ];

  /// The concrete, written policy for a band — pasted into the system prompt.
  static String policyFor(AgeBand band) => switch (band) {
    AgeBand.tiny =>
      'Audience: ages 2–4. Keep it gentle, cozy, and simple with lots of warmth, '
          'animals, and easy feelings. No peril, no scary imagery, only mild and '
          'easily-solved problems.',
    AgeBand.little =>
      'Audience: ages 5–7. Light adventure, friendship, and simple problems that '
          'resolve kindly, plus wonder and gentle STEM. No real danger, no weapons, '
          'no on-page death, no romance.',
    AgeBand.big =>
      'Audience: ages 8–10. Richer plots, mild suspense, and gentle mystery with '
          'stakes that resolve kindly. No graphic violence, no horror, no romance '
          'beyond innocent crushes, no substances.',
    AgeBand.older =>
      'Audience: ages 11+. More complex, friendly themes and mild stakes. Still no '
          'graphic, sexual, or extreme content.',
  };

  /// Highest rating a story may carry for a band (a story may be at or below it).
  static AgeRating ceilingFor(AgeBand band) => switch (band) {
    AgeBand.tiny => AgeRating.tiny,
    AgeBand.little => AgeRating.little,
    AgeBand.big => AgeRating.big,
    AgeBand.older => AgeRating.older,
  };
}

/// Parent-controlled banned themes. Phase 2 uses these defaults; the per-child
/// settings UI comes later. Enforced as a floor on top of the age band.
/// See `docs/safety.md`.
class BannedThemes {
  const BannedThemes._();

  static const List<String> defaults = [
    'sex',
    'drugs',
    'alcohol',
    'flirting',
    'religion',
    'evolution',
    'birthdays',
    'Christmas',
  ];
}
