import 'dart:convert';

/// Stable, dependency-free 64-bit FNV-1a hash of [input] as hex — used as the
/// cache filename. Must stay stable across runs (String.hashCode is not), so we
/// compute it by hand over the UTF-8 bytes.
///
/// Lives apart from `audio_cache.dart` so code that only needs to *name* a
/// cache entry — the chunker, and the read-only probes in `tool/` — doesn't
/// pull in path_provider and, with it, all of Flutter.
String audioCacheKey(String input) {
  const int fnvOffset = 0xcbf29ce484222325;
  const int fnvPrime = 0x100000001b3;
  var hash = fnvOffset;
  for (final b in utf8.encode(input)) {
    hash = (hash ^ b) * fnvPrime; // 64-bit wraparound is intentional
  }
  // Drop the sign bit for a clean, positive hex string (63 bits is plenty of
  // entropy for a filename key).
  return (hash & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}
