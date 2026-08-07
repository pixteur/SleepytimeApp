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

/// The deck of story openings. It holds ~50 cards; the creator shows a random
/// handful ([options]) so the choices feel fresh every night, and the dice
/// ([roll]) picks from the whole deck. See `docs/architecture.md`.
class TwistDeck {
  const TwistDeck();

  /// How many cards the creator offers at once.
  static const int handSize = 6;

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
    Twist(
      id: 'lost_thing',
      label: 'Something goes missing',
      hint:
          'A small treasured thing goes missing and is tracked down together, '
          'with no real danger.',
    ),
    Twist(
      id: 'secret_map',
      label: 'A secret map turns up',
      hint: 'An old hand-drawn map appears and hints at a gentle quest.',
    ),
    Twist(
      id: 'tiny_visitor',
      label: 'A tiny visitor arrives',
      hint:
          'A very small, very polite visitor turns up needing somewhere warm to stay.',
    ),
    Twist(
      id: 'talking_animal',
      label: 'An animal starts talking',
      hint:
          'An ordinary animal turns out to have plenty to say, and something to ask for.',
    ),
    Twist(
      id: 'midnight_snack',
      label: 'A midnight snack adventure',
      hint:
          'A late-night trip to the kitchen turns into a small, cozy adventure.',
    ),
    Twist(
      id: 'shooting_star',
      label: 'A shooting star lands nearby',
      hint:
          'A falling star lands softly close by, still glowing and gently humming.',
    ),
    Twist(
      id: 'rainy_day',
      label: 'The rain changes everything',
      hint:
          'A warm, drumming rain transforms the familiar world into somewhere new.',
    ),
    Twist(
      id: 'first_snow',
      label: 'The first snow falls',
      hint:
          'The first snow of the year hushes everything and invites quiet wonder.',
    ),
    Twist(
      id: 'hidden_room',
      label: 'A hidden room is found',
      hint:
          'A forgotten room is discovered behind something ordinary, full of gentle secrets.',
    ),
    Twist(
      id: 'message_bottle',
      label: 'A message in a bottle',
      hint: 'A bottle washes up with a kind, curious note inside.',
    ),
    Twist(
      id: 'new_neighbour',
      label: 'Someone new moves in',
      hint:
          'A shy newcomer arrives nearby and needs a friend to show them around.',
    ),
    Twist(
      id: 'broken_thing',
      label: 'Something needs fixing',
      hint:
          'A beloved object breaks and is patiently mended, better than before.',
    ),
    Twist(
      id: 'big_race',
      label: 'A friendly race',
      hint:
          'A cheerful, low-stakes race where kindness matters more than winning.',
    ),
    Twist(
      id: 'treasure_hunt',
      label: 'A treasure hunt begins',
      hint:
          'A trail of small clues leads to a warm, surprising sort of treasure.',
    ),
    Twist(
      id: 'everything_huge',
      label: 'Everything grows enormous',
      hint:
          'The world seems suddenly enormous, and small things become grand adventures.',
    ),
    Twist(
      id: 'flying',
      label: 'Suddenly they can fly',
      hint: 'Gentle, floating flight over a familiar place seen from above.',
    ),
    Twist(
      id: 'underwater',
      label: 'Down under the water',
      hint:
          'A calm journey beneath the water, breathing easily among glowing creatures.',
    ),
    Twist(
      id: 'up_a_tree',
      label: 'High up in a tree',
      hint: 'A climb into a huge old tree with a whole world in its branches.',
    ),
    Twist(
      id: 'night_market',
      label: 'A market that opens at night',
      hint:
          'A lantern-lit market that only appears after dark, full of friendly stalls.',
    ),
    Twist(
      id: 'sleepy_dragon',
      label: 'A very sleepy dragon',
      hint:
          'An enormous, entirely gentle creature who mostly just wants a nap.',
    ),
    Twist(
      id: 'delicious_smell',
      label: 'A delicious smell leads the way',
      hint:
          'A wonderful smell drifts through the air and leads somewhere warm and welcoming.',
    ),
    Twist(
      id: 'music_box',
      label: 'A music box plays by itself',
      hint:
          'A small music box begins to play on its own, and its tune means something.',
    ),
    Twist(
      id: 'lantern_parade',
      label: 'A parade of lanterns',
      hint: 'A slow, glowing procession winds through the evening.',
    ),
    Twist(
      id: 'train_ride',
      label: 'A train to somewhere unexpected',
      hint:
          'A cozy train pulls in, bound somewhere nobody has heard of before.',
    ),
    Twist(
      id: 'garden_grows',
      label: 'The garden grows overnight',
      hint:
          'Overnight the garden becomes wonderfully overgrown and full of surprises.',
    ),
    Twist(
      id: 'paper_boat',
      label: 'A paper boat sets sail',
      hint:
          'A folded paper boat is launched and turns out to travel much further than expected.',
    ),
    Twist(
      id: 'lost_kite',
      label: 'A kite gets away',
      hint: 'A kite slips its string, and following it leads somewhere lovely.',
    ),
    Twist(
      id: 'shadow_friend',
      label: 'A shadow acts on its own',
      hint:
          'A shadow starts doing its own playful thing — curious, never frightening.',
    ),
    Twist(
      id: 'unfinished_book',
      label: 'A book that isn’t finished',
      hint:
          'A story book with blank last pages waits for someone to live the ending.',
    ),
    Twist(
      id: 'moon_visit',
      label: 'A visit to the moon',
      hint: 'A soft, slow trip up to the moon and back before morning.',
    ),
    Twist(
      id: 'cloud_castle',
      label: 'A castle in the clouds',
      hint: 'A drifting castle of cloud with pillow-soft rooms to explore.',
    ),
    Twist(
      id: 'dress_up',
      label: 'Dressing up changes everything',
      hint:
          'A costume from an old trunk brings a little unexpected magic with it.',
    ),
    Twist(
      id: 'big_feelings',
      label: 'A big feeling to sort out',
      hint:
          'Someone has a big, hard-to-name feeling, and it is understood and soothed.',
    ),
    Twist(
      id: 'sharing_problem',
      label: 'Two friends want the same thing',
      hint:
          'A gentle disagreement is worked out fairly, and the friendship grows.',
    ),
    Twist(
      id: 'brave_moment',
      label: 'A brave little moment',
      hint:
          'Something mildly daunting is faced with quiet courage and good company.',
    ),
    Twist(
      id: 'new_skill',
      label: 'Learning something tricky',
      hint:
          'A skill that will not work at first finally clicks after patient practice.',
    ),
    Twist(
      id: 'surprise_party',
      label: 'A surprise party to plan',
      hint: 'A secret celebration is planned for someone who deserves it.',
    ),
    Twist(
      id: 'sleepover',
      label: 'A sleepover with friends',
      hint: 'A cozy night in with friends, blanket forts, and whispering.',
    ),
    Twist(
      id: 'small_rescue',
      label: 'A small creature needs rescuing',
      hint:
          'A little creature is stuck somewhere harmless and is carefully helped free.',
    ),
    Twist(
      id: 'wrong_turn',
      label: 'A wrong turn, a lovely place',
      hint: 'Getting a little lost leads somewhere far better than the plan.',
    ),
    Twist(
      id: 'echo_cave',
      label: 'A cave that answers back',
      hint:
          'A friendly echoing cave that seems to reply with more than an echo.',
    ),
    Twist(
      id: 'giant_bubble',
      label: 'A giant bubble floats past',
      hint:
          'An enormous shimmering bubble drifts by, big enough to climb inside.',
    ),
    Twist(
      id: 'mystery_seed',
      label: 'Planting a mysterious seed',
      hint:
          'An unlabelled seed is planted, and nobody knows what will come up.',
    ),
    Twist(
      id: 'long_ago',
      label: 'A peek at long ago',
      hint:
          'A gentle glimpse of how this place looked a very long time in the past.',
    ),
    Twist(
      id: 'wild_invention',
      label: 'Building a wild invention',
      hint:
          'A splendid, slightly ridiculous invention is built out of odds and ends.',
    ),
    Twist(
      id: 'star_in_tree',
      label: 'A star is stuck in a tree',
      hint: 'A small star has tangled itself in the branches and needs a hand.',
    ),
  ];

  /// A random hand of [handSize] distinct cards for the creator. Pass a seeded
  /// [rng] for deterministic tests.
  List<Twist> options({Random? rng, int count = handSize}) {
    final shuffled = [...cards]..shuffle(rng ?? Random());
    return shuffled.take(count.clamp(0, cards.length)).toList();
  }

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
