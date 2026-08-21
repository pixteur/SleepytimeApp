import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'dpapi.dart';
import 'secret_store.dart';

// ─── Win32 DPAPI bindings (crypt32.dll) ───────────────────────────────
// CryptProtectData / CryptUnprotectData encrypt data tied to the current
// Windows user account — secure at-rest storage with no admin and no ATL.

/// Windows secure storage for API keys via DPAPI. The encrypted blob is kept in
/// SharedPreferences (base64); decryption only succeeds for the same Windows
/// user. macOS/iOS will get a Keychain-backed [SecretStore] when those
/// platforms are added. See `docs/ai-providers.md`.
class DpapiSecretStore implements SecretStore {
  String _k(String providerId) => 'enckey_$providerId';

  @override
  Future<void> writeKey(String providerId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(providerId), base64.encode(_encrypt(key)));
  }

  @override
  Future<String?> readKey(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_k(providerId));
    if (stored == null) return null;
    try {
      return _decrypt(base64.decode(stored));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasKey(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_k(providerId)) != null;
  }

  @override
  Future<void> deleteKey(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(providerId));
  }

  Uint8List _encrypt(String plain) => dpapiProtect(plain);

  String _decrypt(Uint8List enc) => dpapiUnprotect(enc);
}
