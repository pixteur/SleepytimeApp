/// The languages a story can be told in or woven with, keyed by the code the
/// prompt and the voice both use.
///
/// Shared by the creator and the story-settings sheet so the two can never
/// drift apart — a language offered in one place and missing from the other
/// would strand a story nobody could edit back.
library;

const Map<String, String> languageChoices = {
  'en': 'English',
  'fr': 'French',
  'es': 'Spanish',
  'ja': 'Japanese',
};

/// The display name for a code, or the code itself if we do not know it.
String languageLabel(String code) => languageChoices[code] ?? code;
