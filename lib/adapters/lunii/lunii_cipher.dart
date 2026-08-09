/// The cipher guarding a Lunii storyteller's story packs.
///
/// It is a *modified* XXTEA: the round count is `1 + 52/n` where stock XXTEA
/// uses `6 + 52/n`, so a full 512-byte block gets exactly one round. Only the
/// first [luniiCipherBlock] bytes of a file are ever ciphered — one flash
/// sector — and the tail is left in the clear, which is why an MP3 on the
/// device still shows plain frame headers past byte 512.
///
/// Two keys are in play:
///
/// * [luniiGenericKey] ("key A") is the same on every device and covers `li`,
///   `ri`, `si` and every asset under `rf/` and `sf/`. Note that `ni`, the
///   node index, is stored in the clear despite being an index — deciphering
///   it corrupts the header.
/// * A device-specific key ("key B") protects only the per-pack `bt` boot
///   file, which is what ties a pack to one storyteller. [luniiDeviceKey]
///   recovers it from the device's `.md`.
///
/// Format from the community reverse-engineering work at
/// <https://github.com/o-daneel/Lunii.RE>, verified against a physical FW2
/// device. See `docs/lunii-sync.md`.
library;

import 'dart:typed_data';

/// "Key A" — hardcoded, identical on every storyteller.
const List<int> luniiGenericKey = <int>[
  0x91BD7A0A,
  0xA75440A9,
  0xBBD49D6C,
  0xE0DCC0E3,
];

/// Only the first sector of any pack file is ciphered.
const int luniiCipherBlock = 512;

const int _delta = 0x9E3779B9;
const int _mask = 0xFFFFFFFF;

/// Decipher the leading [luniiCipherBlock] bytes of [data] in place-safe
/// fashion, returning a new list with the tail copied through untouched.
Uint8List luniiDecipher(Uint8List data, List<int> key) =>
    _transform(data, key, decipher: true);

/// The inverse of [luniiDecipher] — used when writing a pack to the device.
Uint8List luniiCipher(Uint8List data, List<int> key) =>
    _transform(data, key, decipher: false);

Uint8List _transform(Uint8List data, List<int> key, {required bool decipher}) {
  final out = Uint8List.fromList(data);
  // A partial word at the end of a short file is left alone: the cipher works
  // on whole 32-bit words.
  final blockBytes =
      (out.length < luniiCipherBlock ? out.length : luniiCipherBlock) & ~3;
  if (blockBytes < 8) return out;

  final view = ByteData.sublistView(out, 0, blockBytes);
  final words = Uint32List(blockBytes ~/ 4);
  for (var i = 0; i < words.length; i++) {
    words[i] = view.getUint32(i * 4, Endian.little);
  }
  if (decipher) {
    _decipherWords(words, key);
  } else {
    _cipherWords(words, key);
  }
  for (var i = 0; i < words.length; i++) {
    view.setUint32(i * 4, words[i], Endian.little);
  }
  return out;
}

int _mx(int y, int z, int sum, int e, int p, List<int> key) {
  final shifted =
      (((z >> 5) ^ ((y << 2) & _mask)) + ((y >> 3) ^ ((z << 4) & _mask))) &
      _mask;
  final keyed = ((sum ^ y) + (key[(p & 3) ^ e] ^ z)) & _mask;
  return (shifted ^ keyed) & _mask;
}

/// The one deviation from stock XXTEA, and the whole reason a hand-rolled
/// implementation is needed: stock uses `6 + 52 ~/ n`.
int _rounds(int n) => 1 + 52 ~/ n;

void _cipherWords(Uint32List v, List<int> key) {
  final n = v.length;
  if (n < 2) return;
  var rounds = _rounds(n);
  var sum = 0;
  var z = v[n - 1];
  var y = 0;
  do {
    sum = (sum + _delta) & _mask;
    final e = (sum >> 2) & 3;
    for (var p = 0; p < n - 1; p++) {
      y = v[p + 1];
      z = v[p] = (v[p] + _mx(y, z, sum, e, p, key)) & _mask;
    }
    y = v[0];
    z = v[n - 1] = (v[n - 1] + _mx(y, z, sum, e, n - 1, key)) & _mask;
  } while (--rounds > 0);
}

void _decipherWords(Uint32List v, List<int> key) {
  final n = v.length;
  if (n < 2) return;
  var rounds = _rounds(n);
  var sum = (rounds * _delta) & _mask;
  var y = v[0];
  var z = 0;
  do {
    final e = (sum >> 2) & 3;
    for (var p = n - 1; p > 0; p--) {
      z = v[p - 1];
      y = v[p] = (v[p] - _mx(y, z, sum, e, p, key)) & _mask;
    }
    z = v[n - 1];
    y = v[0] = (v[0] - _mx(y, z, sum, e, 0, key)) & _mask;
    sum = (sum - _delta) & _mask;
  } while (--rounds > 0);
}

/// Recover the device-specific "key B" from the 512-byte `.md` at the root of
/// a storyteller's drive.
///
/// The whole second half of `.md` — 0x100 bytes at offset 0x100 — is itself
/// ciphered with [luniiGenericKey]. The key is the first 16 bytes of that
/// plaintext with its two halves swapped (`plain[8:16] + plain[0:8]`), read as
/// four little-endian words.
///
/// The block length matters: at 0x100 bytes it is 64 words, so [_rounds] gives
/// one round. Deciphering a shorter slice would run a different number of
/// rounds and silently produce a wrong key.
List<int> luniiDeviceKey(Uint8List md, {int blockOffset = 0x100}) {
  const blockLength = 0x100;
  if (md.length < blockOffset + blockLength) {
    throw ArgumentError.value(
      md.length,
      'md',
      'A .md needs $blockLength bytes at offset '
          '0x${blockOffset.toRadixString(16)}',
    );
  }
  final block = md.sublist(blockOffset, blockOffset + blockLength);
  final plain = luniiDecipher(block, luniiGenericKey);
  final view = ByteData.sublistView(plain);
  return <int>[
    view.getUint32(8, Endian.little),
    view.getUint32(12, Endian.little),
    view.getUint32(0, Endian.little),
    view.getUint32(4, Endian.little),
  ];
}
