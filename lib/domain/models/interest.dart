/// A "new interest" nudge — parent-added or inferred from play. Biases future
/// stories toward what the child loves. See `docs/data-model.md`.
class Interest {
  const Interest({
    required this.id,
    required this.childId,
    required this.label,
    this.weight = 1,
    this.active = true,
    this.source = InterestSource.parent,
  });

  final String id;
  final String childId;

  /// e.g. "Jupiter", "fractals", "dinosaurs".
  final String label;

  /// How strongly to nudge (parent-tunable).
  final int weight;
  final bool active;
  final InterestSource source;
}

enum InterestSource { quiz, parent, inferred }
