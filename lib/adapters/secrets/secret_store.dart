/// OS-secure storage for API keys (Windows Credential Manager / macOS & iOS
/// Keychain). Keys are NEVER written to the DB, logged, or committed.
/// Concrete impl arrives in Phase 2. See `docs/ai-providers.md`.
abstract class SecretStore {
  Future<void> writeKey(String providerId, String key);

  /// A displayable reminder of a key — first four and last four characters,
  /// e.g. `AIza••••7f2c`. Never enough to use or reconstruct the key, so it is
  /// safe to keep in ordinary preferences and show on screen. A key too short
  /// to mask usefully returns empty rather than leaking most of itself.
  static String hintFor(String key) {
    final k = key.trim();
    if (k.length < 12) return '';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

  Future<String?> readKey(String providerId);
  Future<bool> hasKey(String providerId);
  Future<void> deleteKey(String providerId);
}
