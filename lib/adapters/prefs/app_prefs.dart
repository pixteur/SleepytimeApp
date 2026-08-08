import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight non-secret app preferences (consent flags, selected model).
/// API keys live in [SecretStore], never here. See `docs/safety.md`.
class AppPrefs {
  AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppPrefs> open() async =>
      AppPrefs(await SharedPreferences.getInstance());

  static const _aiConsentKey = 'ai_third_party_consent';
  static const _providerKey = 'selected_provider';

  /// Whether the parent has explicitly consented to sending story prompts +
  /// profile-derived context to a third-party AI provider. Required before any
  /// real provider is used (per CLAUDE.md / docs/safety.md).
  bool get aiConsentGiven => _prefs.getBool(_aiConsentKey) ?? false;

  Future<void> setAiConsent(bool value) => _prefs.setBool(_aiConsentKey, value);

  /// The chosen provider name (`claude` / `openai` / `gemini`). Default `claude`.
  String get selectedProvider => _prefs.getString(_providerKey) ?? 'claude';

  Future<void> setSelectedProvider(String name) =>
      _prefs.setString(_providerKey, name);

  // ── API key hints ───────────────────────────────────────────────

  /// A non-sensitive reminder of which key is stored for a provider, e.g.
  /// `AIza••••7f2c`, so a parent can tell at a glance *which* key is saved
  /// without the app ever reading the secret back out of the OS key store.
  /// Empty when no key is saved. Written alongside the key; cleared with it.
  String keyHint(String keyName) => _prefs.getString(_hintKey(keyName)) ?? '';

  Future<void> setKeyHint(String keyName, String hint) =>
      _prefs.setString(_hintKey(keyName), hint);

  Future<void> clearKeyHint(String keyName) =>
      _prefs.remove(_hintKey(keyName));

  static String _hintKey(String keyName) => 'key_hint_$keyName';

  // ── Voice ───────────────────────────────────────────────────────
  static const _voiceEngineKey = 'voice_engine';

  /// The chosen voice engine (`device` / `openai` / `elevenlabs` / `gemini`).
  /// Default `device` (free, offline).
  String get voiceEngine => _prefs.getString(_voiceEngineKey) ?? 'device';

  Future<void> setVoiceEngine(String name) =>
      _prefs.setString(_voiceEngineKey, name);

  /// The selected voice/voice-id for an engine (null → engine default).
  String? voiceName(String engine) => _prefs.getString('voicename_$engine');

  Future<void> setVoiceName(String engine, String name) =>
      _prefs.setString('voicename_$engine', name);

  // ── Parent mode ─────────────────────────────────────────────────
  static const _parentModeKey = 'parent_mode';

  /// When true, grown-up controls (delete, rename) are visible. Default false
  /// ("child mode") so a child can't accidentally delete or edit stories.
  bool get parentMode => _prefs.getBool(_parentModeKey) ?? false;

  Future<void> setParentMode(bool value) =>
      _prefs.setBool(_parentModeKey, value);

  // ── Demo seed ───────────────────────────────────────────────────
  /// Whether the bundled demo story has already been offered to this child (so
  /// we only auto-seed an empty bookshelf once).
  bool demoSeeded(String childId) =>
      _prefs.getBool('demo_seeded_$childId') ?? false;

  Future<void> setDemoSeeded(String childId) =>
      _prefs.setBool('demo_seeded_$childId', true);
}
