/// Windows DPAPI, on its own.
///
/// `CryptProtectData` / `CryptUnprotectData` encrypt bytes against the current
/// Windows user account — at-rest security with no admin rights and no extra
/// dependency. Split out from [DpapiSecretStore] so that anything needing to
/// read a stored key can, without dragging in SharedPreferences and, through
/// it, all of Flutter: the read-only probes in `tool/` run under plain
/// `dart run`. Same reason `audio_cache_key.dart` sits apart from its cache.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

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

final DynamicLibrary _crypt32 = DynamicLibrary.open('crypt32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

final _protect = _crypt32.lookupFunction<_CryptNative, _CryptDart>(
  'CryptProtectData',
);
final _unprotect = _crypt32.lookupFunction<_CryptNative, _CryptDart>(
  'CryptUnprotectData',
);
final _localFree = _kernel32
    .lookupFunction<Pointer<Void> Function(Pointer<Void>), _LocalFree>(
      'LocalFree',
    );

/// Encrypt [plain] for the current Windows user.
Uint8List dpapiProtect(String plain) =>
    _run(Uint8List.fromList(utf8.encode(plain)), _protect, 'CryptProtectData');

/// Decrypt what [dpapiProtect] produced. Throws for another user's blob.
String dpapiUnprotect(Uint8List encrypted) =>
    utf8.decode(_run(encrypted, _unprotect, 'CryptUnprotectData'));

/// Shared call with careful cleanup: DPAPI allocates the output itself, so it
/// is freed with LocalFree while our own buffers go back to calloc.
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
