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
