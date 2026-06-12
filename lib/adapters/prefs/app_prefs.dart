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
}
