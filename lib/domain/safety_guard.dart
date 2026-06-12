import 'age_policy.dart';
import 'models/child_profile.dart';
import 'models/story_segment.dart';

/// The result of a safety review.
class SafetyVerdict {
  const SafetyVerdict(this.ok, [this.reasons = const []]);

  final bool ok;
  final List<String> reasons;
}

/// The output guardrail (Layer 3). Every generated segment is reviewed BEFORE it
/// can be shown or spoken: rating must fit the band, no banned themes, not empty,
/// no model-flagged sensitive content. The engine handles retries + the
/// never-break-bedtime fallback. See `docs/safety.md`.
class SafetyGuard {
  const SafetyGuard();

  SafetyVerdict review(
    StorySegment segment, {
    required AgeBand band,
    List<String> bannedThemes = BannedThemes.defaults,
  }) {
    final reasons = <String>[];

    if (segment.storyText.trim().isEmpty) {
      reasons.add('empty story text');
    }

    if (segment.rating.index > AgePolicy.ceilingFor(band).index) {
      reasons.add(
        'rating "${segment.rating.name}" exceeds the "${band.name}" band',
      );
    }

    final haystack = '${segment.storyText} ${segment.summary}'.toLowerCase();
    for (final theme in bannedThemes) {
      if (_mentions(haystack, theme.toLowerCase())) {
        reasons.add('mentions banned theme: $theme');
      }
    }

    if (segment.sensitiveFlags.isNotEmpty) {
      reasons.add('model-flagged: ${segment.sensitiveFlags.join(', ')}');
    }

    return SafetyVerdict(reasons.isEmpty, reasons);
  }

  /// Whole-word, case-insensitive match so "grape" doesn't trip "rape", etc.
  bool _mentions(String text, String term) {
    final pattern = RegExp(
      '\\b${RegExp.escape(term)}\\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }
}
