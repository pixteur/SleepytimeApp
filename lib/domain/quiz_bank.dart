/// The onboarding questions, and the thinking behind them.
///
/// The first version asked what the story should be: a creature, a place, a
/// companion, a mood. Two things went wrong with that.
///
/// **Every child picked the dragon.** Offer a five-year-old "Dragon, Puppy,
/// Robot, Something else" and the dragon wins, every time, for every child —
/// so the answer says nothing about *this* child. A question only tells you
/// something when the options are equally attractive and the choice between
/// them is a matter of taste. So none of these has an obviously best answer;
/// each is a fork between two things a child could genuinely want.
///
/// **And it asked the story creator's questions.** Creature, place, companion
/// and length are all chosen again when a story is made, where they belong —
/// they are about tonight, not about the child. Asking twice wasted the one
/// moment a child is willing to answer questions, and the answers went stale
/// the moment their taste moved on.
///
/// So these ask who the child *is*: how they like to poke at a problem, who
/// they want beside them, what settles them at the end of a day, what makes
/// them laugh, how much excitement is fun rather than too much. Those hold
/// steady for years and steer every story, where "dragon" steers one.
///
/// One question is drawn at random per dimension, so a second child in the
/// same house is asked differently and the answers stay theirs rather than
/// copied from a sibling. See `docs/data-model.md`.
library;

import 'dart:math';

import 'models/quiz_question.dart';

/// Every question, grouped by what it is trying to learn.
const Map<QuizDimension, List<QuizQuestion>> quizBank = {
  QuizDimension.curiosity: [
    QuizQuestion(
      id: 'curiosity_box',
      prompt:
          'Which is better: a locked box with no key, or a path you have '
          'never walked down?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.curiosity,
      choices: [
        QuizChoice('The locked box', 'loves a puzzle to work out'),
        QuizChoice('The new path', 'loves exploring somewhere unknown'),
      ],
    ),
    QuizQuestion(
      id: 'curiosity_build',
      prompt:
          'Would you rather build something new, or find out how '
          'something works?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.curiosity,
      choices: [
        QuizChoice('Build something', 'likes making and inventing'),
        QuizChoice('Find out how', 'likes taking things apart to understand'),
      ],
    ),
    QuizQuestion(
      id: 'curiosity_question',
      prompt: 'Is it more fun to know the answer, or to still be wondering?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.curiosity,
      choices: [
        QuizChoice('To know', 'likes things explained and settled'),
        QuizChoice('To wonder', 'enjoys mystery and open questions'),
      ],
    ),
    QuizQuestion(
      id: 'curiosity_first',
      prompt:
          'In a new place, do you look around first, or touch things '
          'first?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.curiosity,
      choices: [
        QuizChoice('Look first', 'watches and takes it in before acting'),
        QuizChoice('Touch first', 'learns by doing, hands first'),
      ],
    ),
  ],
  QuizDimension.company: [
    QuizQuestion(
      id: 'company_alone',
      prompt:
          'Something brilliant happens. Is it better on your own, or with '
          'one good friend?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.company,
      choices: [
        QuizChoice('On my own', 'happy alone, quietly self-contained'),
        QuizChoice('With a friend', 'wants one close friend beside them'),
      ],
    ),
    QuizQuestion(
      id: 'company_role',
      prompt:
          'Would you rather be the one who leads the way, or the one who '
          'notices what everyone missed?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.company,
      choices: [
        QuizChoice('Lead the way', 'takes charge and decides'),
        QuizChoice('Notice things', 'observant, spots what others do not'),
      ],
    ),
    QuizQuestion(
      id: 'company_who',
      prompt:
          'If someone came with you, should they be brave, funny, or '
          'clever?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.company,
      choices: [
        QuizChoice('Brave', 'values courage in a companion'),
        QuizChoice('Funny', 'values humour in a companion'),
        QuizChoice('Clever', 'values cleverness in a companion'),
      ],
    ),
    QuizQuestion(
      id: 'company_help',
      prompt: 'Is it better to be helped, or to be the one helping?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.company,
      choices: [
        QuizChoice('Being helped', 'likes being looked after'),
        QuizChoice('Helping', 'likes looking after others'),
      ],
    ),
  ],
  QuizDimension.comfort: [
    QuizQuestion(
      id: 'comfort_place',
      prompt:
          'What makes a place feel safe: soft blankets, a light left on, '
          'or someone humming nearby?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.comfort,
      choices: [
        QuizChoice('Soft blankets', 'soothed by warmth and softness'),
        QuizChoice('A light on', 'soothed by a little light in the dark'),
        QuizChoice('Someone humming', 'soothed by a voice or music nearby'),
      ],
    ),
    QuizQuestion(
      id: 'comfort_afterday',
      prompt:
          'After a big day, is it better to be very quiet, or to hear '
          'someone talking softly?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.comfort,
      choices: [
        QuizChoice('Very quiet', 'winds down in stillness'),
        QuizChoice('Someone talking', 'winds down to a gentle voice'),
      ],
    ),
    QuizQuestion(
      id: 'comfort_weather',
      prompt: 'Best sleepy weather: rain on the window, or deep snow outside?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.comfort,
      choices: [
        QuizChoice('Rain', 'comforted by rain and cosy indoor sounds'),
        QuizChoice('Snow', 'comforted by hush and stillness'),
      ],
    ),
  ],
  QuizDimension.humour: [
    QuizQuestion(
      id: 'humour_kind',
      prompt:
          'Funniest: someone slipping in a puddle, a very serious cat, or '
          'a joke you have to think about?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.humour,
      choices: [
        QuizChoice('The puddle', 'laughs at big, silly, physical comedy'),
        QuizChoice('The serious cat', 'laughs at absurdity played straight'),
        QuizChoice('The joke', 'enjoys wordplay and jokes with a turn in them'),
      ],
    ),
    QuizQuestion(
      id: 'humour_mischief',
      prompt:
          'Is it funnier when someone plans a trick, or when everything '
          'goes wrong by accident?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.humour,
      choices: [
        QuizChoice('A planned trick', 'enjoys mischief and cleverness'),
        QuizChoice('Everything wrong', 'enjoys chaos and mix-ups'),
      ],
    ),
  ],
  QuizDimension.intensity: [
    QuizQuestion(
      id: 'intensity_known',
      prompt:
          'In a story, is it better to know everything will be fine, or '
          'to be surprised?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.intensity,
      choices: [
        QuizChoice('Know it is fine', 'wants reassurance, very low jeopardy'),
        QuizChoice('Be surprised', 'enjoys a twist and mild suspense'),
      ],
    ),
    QuizQuestion(
      id: 'intensity_speed',
      prompt:
          'Would you rather a story where lots happens, or one where you '
          'stay in one place and look closely?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.intensity,
      choices: [
        QuizChoice('Lots happens', 'likes pace and plenty of event'),
        QuizChoice('Look closely', 'likes slow, detailed, atmospheric stories'),
      ],
    ),
  ],
  QuizDimension.fascination: [
    QuizQuestion(
      id: 'fascination_hour',
      prompt: 'What could you talk about for a whole hour?',
      type: QuizAnswerType.freeText,
      dimension: QuizDimension.fascination,
      seedsInterest: true,
    ),
    QuizQuestion(
      id: 'fascination_twice',
      prompt: 'What did you look at twice today?',
      type: QuizAnswerType.freeText,
      dimension: QuizDimension.fascination,
      seedsInterest: true,
    ),
    QuizQuestion(
      id: 'fascination_collect',
      prompt: 'Is there something you collect, or keep, or know a lot about?',
      type: QuizAnswerType.freeText,
      dimension: QuizDimension.fascination,
      seedsInterest: true,
    ),
    QuizQuestion(
      id: 'fascination_best',
      prompt: 'What is the best thing in your room?',
      type: QuizAnswerType.freeText,
      dimension: QuizDimension.fascination,
      seedsInterest: true,
    ),
  ],
  QuizDimension.avoid: [
    QuizQuestion(
      id: 'avoid_bedtime',
      prompt: 'Anything you would rather NOT hear about at bedtime?',
      type: QuizAnswerType.freeText,
      dimension: QuizDimension.avoid,
      isSoftSafetyHint: true,
    ),
  ],
  QuizDimension.length: [
    QuizQuestion(
      id: 'length',
      prompt: 'How long should stories be?',
      type: QuizAnswerType.choice,
      dimension: QuizDimension.length,
      setsDetailLevel: true,
      choices: [
        QuizChoice('Short', 'short'),
        QuizChoice('Medium', 'medium'),
        QuizChoice('Long', 'long'),
      ],
    ),
  ],
};

/// The order questions are asked in. Deliberate rather than shuffled: the
/// easy, playful ones first, the free-text ones once the child is warmed up,
/// and the settling question last so the quiz itself ends calmly.
const List<QuizDimension> quizOrder = [
  QuizDimension.curiosity,
  QuizDimension.company,
  QuizDimension.humour,
  QuizDimension.fascination,
  QuizDimension.intensity,
  QuizDimension.comfort,
  QuizDimension.avoid,
  QuizDimension.length,
];

/// One question per dimension, drawn at random.
///
/// Pass a seeded [Random] to pin the draw in a test. The same child answering
/// again gets a different set, which is the point: a second pass should learn
/// something new rather than re-ask what is already known.
List<QuizQuestion> drawQuiz([Random? rng]) {
  final random = rng ?? Random();
  return [
    for (final dimension in quizOrder)
      quizBank[dimension]![random.nextInt(quizBank[dimension]!.length)],
  ];
}

/// Look up a question anywhere in the bank by its id.
QuizQuestion? questionById(String id) {
  for (final questions in quizBank.values) {
    for (final q in questions) {
      if (q.id == id) return q;
    }
  }
  return null;
}
