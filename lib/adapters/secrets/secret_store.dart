/// OS-secure storage for API keys (Windows Credential Manager / macOS & iOS
/// Keychain). Keys are NEVER written to the DB, logged, or committed.
/// Concrete impl arrives in Phase 2. See `docs/ai-providers.md`.
abstract class SecretStore {
  Future<void> writeKey(String providerId, String key);
  Future<String?> readKey(String providerId);
  Future<bool> hasKey(String providerId);
  Future<void> deleteKey(String providerId);
}
