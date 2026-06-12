/// One child's account — the unit every story is personalized for.
///
/// Pure Dart, no Flutter imports (domain layer). See `docs/data-model.md`.
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.displayName,
    required this.age,
    this.language = 'en',
    this.detailLevel = DetailLevel.medium,
    this.themeColor = 0xFF6750A4,
    this.parentBrief,
  });

  final String id;

  /// Kid-chosen nickname; we deliberately avoid real full names (privacy).
  final String displayName;
  final int age;

  /// BCP-47-ish language tag for UI + story generation (`en`, `fr`, `es`, `ja`).
  final String language;
  final DetailLevel detailLevel;

  /// ARGB seed colour for per-child theming.
  final int themeColor;

  /// Optional free-text from a parent expressing values/tone. See `docs/safety.md`.
  final String? parentBrief;

  /// The age band drives the safety policy injected into every prompt.
  AgeBand get ageBand => AgeBand.forAge(age);
}

enum DetailLevel { short, medium, long }

/// Coarse age bands with concrete safety policies. See `docs/safety.md`.
enum AgeBand {
  tiny, // 2–4
  little, // 5–7
  big, // 8–10
  older; // 11+

  static AgeBand forAge(int age) {
    if (age <= 4) return AgeBand.tiny;
    if (age <= 7) return AgeBand.little;
    if (age <= 10) return AgeBand.big;
    return AgeBand.older;
  }
}
