import 'provider_exceptions.dart';

/// Retry [action] on HTTP 429 (rate limit) with exponential backoff.
///
/// Gemini's free tier caps requests per minute (e.g. 10/min for TTS) and
/// returns 429 with a short "retry in ~1s" window, so a few spaced retries
/// recover transparently instead of failing the narration/story. Non-429 errors
/// rethrow immediately; gives up (rethrows the 429) after [maxAttempts].
///
/// [cancelled] lets a caller bail out early (e.g. the user stopped playback).
Future<T> retryOnRateLimit<T>(
  Future<T> Function() action, {
  int maxAttempts = 4,
  Duration firstDelay = const Duration(milliseconds: 1500),
  bool Function()? cancelled,
}) async {
  var delay = firstDelay;
  for (var attempt = 1; ; attempt++) {
    try {
      return await action();
    } on ProviderRequestException catch (e) {
      final giveUp =
          e.statusCode != 429 ||
          attempt >= maxAttempts ||
          (cancelled?.call() ?? false);
      if (giveUp) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}
