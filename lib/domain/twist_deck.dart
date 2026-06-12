import 'dart:math';

/// One twist offered as an option card or dice outcome. Fixed categories with
/// kid-facing labels + a `hint` that steers the prompt. Parent-tunable tone
/// comes later. See `docs/ui-ux.md`.
class Twist {
  const Twist({required this.id, required this.label, required this.hint});

  /// Stable category id (also used as the LearnedProfile twist tag).
  final String id;

  /// Kid-facing card label.
  final String label;

  /// Steer text fed into the prompt.
  final String hint;
}

/// Supplies the six option cards and the dice roll. See `docs/architecture.md`.
class TwistDeck {
  const TwistDeck();

  static const List<Twist> cards = [
    Twist(
      id: 'mystery_door',
      label: 'A mysterious door appears',
      hint:
          'A friendly, intriguing door or passage appears, inviting gentle exploration.',
    ),
    Twist(
      id: 'someone_needs_help',
      label: 'Someone needs help',
      hint:
          'A kind character needs a small bit of help, solved with teamwork and care.',
    ),
    Twist(
      id: 'silly_mixup',
      label: 'A silly mix-up happens',
      hint: 'A light, giggly mix-up sets up some gentle comedy.',
    ),
    Twist(
      id: 'new_place',
      label: 'Explore somewhere new',
      hint: 'The journey moves to a wondrous new place to discover.',
    ),
    Twist(
      id: 'old_friend',
      label: 'An old friend returns',
      hint: 'A beloved recurring character returns with warmth.',
    ),
    Twist(
      id: 'gentle_surprise',
      label: 'A gentle surprise',
      hint: 'A soft, happy surprise brings a smile.',
    ),
  ];

  /// The six option cards.
  List<Twist> options() => cards;

  /// Pick one at random (the dice). Pass a seeded [Random] for deterministic tests.
  Twist roll([Random? rng]) => cards[(rng ?? Random()).nextInt(cards.length)];

  /// Look up a twist by its stable id.
  Twist? byId(String id) {
    for (final t in cards) {
      if (t.id == id) return t;
    }
    return null;
  }
}
