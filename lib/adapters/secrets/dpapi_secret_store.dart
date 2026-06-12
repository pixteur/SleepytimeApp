import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';

// ─── Win32 DPAPI bindings (crypt32.dll) ───────────────────────────────
// CryptProtectData / CryptUnprotectData encrypt data tied to the current
// Windows user account — secure at-rest storage with no admin and no ATL.

final class _Blob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _CryptNative =
    Int32 Function(
      Pointer<_Blob> dataIn,
      Pointer<Utf16> description,
      Pointer<_Blob> entropy,
      Pointer<Void> reserved,
      Pointer<Void> prompt,
      Uint32 flags,
      Pointer<_Blob> dataOut,
    );
typedef _CryptDart =
    int Function(
      Pointer<_Blob> dataIn,
      Pointer<Utf16> description,
      Pointer<_Blob> entropy,
      Pointer<Void> reserved,
      Pointer<Void> prompt,
      int flags,
      Pointer<_Blob> dataOut,
    );
typedef _LocalFree = Pointer<Void> Function(Pointer<Void>);

/// Windows secure storage for API keys via DPAPI. The encrypted blob is kept in
/// SharedPreferences (base64); decryption only succeeds for the same Windows
/// user. macOS/iOS will get a Keychain-backed [SecretStore] when those
/// platforms are added. See `docs/ai-providers.md`.
class DpapiSecretStore implements SecretStore {
  static final DynamicLibrary _crypt32 = DynamicLibrary.open('crypt32.dll');
  static final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final _protect = _crypt32.lookupFunction<_CryptNative, _CryptDart>(
    'CryptProtectData',
  );
  static final _unprotect = _crypt32.lookupFunction<_CryptNative, _CryptDart>(
    'CryptUnprotectData',
  );
  static final _localFree = _kernel32
      .lookupFunction<Pointer<Void> Function(Pointer<Void>), _LocalFree>(
        'LocalFree',
      );

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

  Uint8List _encrypt(String plain) => _run(
    Uint8List.fromList(utf8.encode(plain)),
    _protect,
    'CryptProtectData',
  );

  String _decrypt(Uint8List enc) =>
      utf8.decode(_run(enc, _unprotect, 'CryptUnprotectData'));

  /// Shared CryptProtectData/CryptUnprotectData call with careful cleanup.
  Uint8List _run(Uint8List input, _CryptDart fn, String name) {
    final pIn = calloc<Uint8>(input.length);
    pIn.asTypedList(input.length).setAll(0, input);
    final inBlob = calloc<_Blob>()
      ..ref.cbData = input.length
      ..ref.pbData = pIn;
    final outBlob = calloc<_Blob>();
    try {
      final ok = fn(inBlob, nullptr, nullptr, nullptr, nullptr, 0, outBlob);
      if (ok == 0) throw Exception('$name failed');
      final result = Uint8List.fromList(
        outBlob.ref.pbData.asTypedList(outBlob.ref.cbData),
      );
      _localFree(outBlob.ref.pbData.cast());
      return result;
    } finally {
      calloc.free(pIn);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }
}
