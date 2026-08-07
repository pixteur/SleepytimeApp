// Shared typed errors for AI providers. The StoryEngine catches these and
// falls back to a safe beat so bedtime never breaks. See `docs/ai-providers.md`.

/// No API key configured for the active provider.
class ProviderNotConfigured implements Exception {
  const ProviderNotConfigured(this.message);
  final String message;
  @override
  String toString() => 'ProviderNotConfigured: $message';
}

/// The model declined to generate (safety refusal / blocked).
class ProviderRefusal implements Exception {
  const ProviderRefusal(this.message);
  final String message;
  @override
  String toString() => 'ProviderRefusal: $message';
}

/// A non-200 response, or an unparseable / malformed body.
class ProviderRequestException implements Exception {
  const ProviderRequestException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ProviderRequestException($statusCode): $message';
}

/// A short, parent-friendly sentence for a voice/story-AI error — no status
/// codes or stack-trace text. Use for anything shown to the user.
String friendlyProviderError(Object error) {
  if (error is ProviderNotConfigured) {
    return 'No voice is set up yet — add one in Voice setup.';
  }
  if (error is ProviderRefusal) {
    return 'The storyteller skipped this one. Try again or pick another voice.';
  }
  if (error is ProviderRequestException) {
    if (error.statusCode == 429) {
      final m = error.message.toLowerCase();
      if (m.contains('per_day') ||
          m.contains('quota') ||
          m.contains('billing')) {
        return 'You\'ve used today\'s free voice quota (your key is fine). It '
            'resets in a few hours — or raise the limit in your provider\'s plan.';
      }
      return 'The voice is busy right now. Please try again in a moment.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'That voice key was turned away — please check it in Voice setup.';
    }
    if (error.statusCode >= 500) {
      return 'The voice service had a little hiccup. Please try again soon.';
    }
    return 'The narration couldn\'t be prepared just now. Please try again.';
  }
  final s = error.toString().toLowerCase();
  if (s.contains('socket') ||
      s.contains('network') ||
      s.contains('connection') ||
      s.contains('handshake') ||
      s.contains('failed host')) {
    return 'Couldn\'t reach the voice service — please check your connection.';
  }
  return 'The narration couldn\'t be downloaded just now. Please try again.';
}
