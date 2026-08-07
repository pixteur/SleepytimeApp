import 'dart:convert';

/// Pending changes to a [World]'s cast that the *next* story must acknowledge:
/// characters the grown-up just added (introduce them warmly) and characters
/// they removed (write them out gently — never just vanish them).
///
/// Recorded when the cast is edited, consumed by the next generated chapter,
/// then cleared. See `docs/data-model.md`.
class CastChanges {
  const CastChanges({this.joined = const [], this.left = const []});

  /// Prompt lines for newly added characters, e.g. "Mo — a shy hedgehog".
  final List<String> joined;

  /// Prompt lines for removed characters, who need a send-off.
  final List<String> left;

  bool get isEmpty => joined.isEmpty && left.isEmpty;
  bool get isNotEmpty => !isEmpty;

  CastChanges withJoined(String line) =>
      CastChanges(joined: [...joined, line], left: left);

  /// Record a departure. If the character had only just been added and never
  /// appeared in a story, drop them silently instead — there is nobody to say
  /// goodbye to.
  CastChanges withLeft(String line, {required String name}) {
    final wasPending = joined.any((j) => _nameOf(j) == name);
    return CastChanges(
      joined: joined.where((j) => _nameOf(j) != name).toList(),
      left: wasPending ? left : [...left, line],
    );
  }

  static String _nameOf(String promptLine) =>
      promptLine.split('—').first.trim();

  static const CastChanges none = CastChanges();

  Map<String, dynamic> toJson() => {'joined': joined, 'left': left};

  static CastChanges fromJson(Map<String, dynamic> json) =>
      CastChanges(joined: _list(json['joined']), left: _list(json['left']));

  String encode() => isEmpty ? '{}' : jsonEncode(toJson());

  static CastChanges decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return none;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return none;
    }
  }

  static List<String> _list(Object? value) =>
      (value as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}
