import 'dart:io' show gzip;
import 'dart:typed_data';

/// Lossless background compression for cached narration. Cloud WAV (16-bit PCM)
/// is bulky; delta-coding the samples (store sample-to-sample differences, which
/// are small for speech) makes gzip far more effective — typically ~2× smaller,
/// with no quality loss. Already-compressed audio (MP3) is just gzipped.
///
/// Wire format: `'SZ1'` + flag byte (1 = delta+gzip WAV, 0 = gzip only) + gzip
/// payload. Anything without the `SZ1` magic is treated as legacy/plain bytes,
/// so old uncompressed cache files still read. See `docs/storage-layout.md`.
const List<int> _magic = [0x53, 0x5A, 0x31]; // 'SZ1'

Uint8List compressAudio(Uint8List bytes) {
  final isWav =
      bytes.length > 44 &&
      bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46; //  F
  final Uint8List payload;
  final int flag;
  if (isWav) {
    payload = _deltaEncode(bytes);
    flag = 1;
  } else {
    payload = bytes;
    flag = 0;
  }
  final gz = gzip.encode(payload);
  final out = Uint8List(4 + gz.length)
    ..[0] = _magic[0]
    ..[1] = _magic[1]
    ..[2] = _magic[2]
    ..[3] = flag
    ..setRange(4, 4 + gz.length, gz);
  return out;
}

Uint8List decompressAudio(Uint8List bytes) {
  if (bytes.length < 4 ||
      bytes[0] != _magic[0] ||
      bytes[1] != _magic[1] ||
      bytes[2] != _magic[2]) {
    return bytes; // legacy / already-plain audio
  }
  final flag = bytes[3];
  final payload = Uint8List.fromList(gzip.decode(bytes.sublist(4)));
  return flag == 1 ? _deltaDecode(payload) : payload;
}

/// Replace each 16-bit sample with its difference from the previous one. Header
/// (first 44 bytes) and any trailing odd byte are preserved verbatim.
Uint8List _deltaEncode(Uint8List wav) {
  final out = Uint8List.fromList(wav);
  final inView = ByteData.sublistView(wav);
  final outView = ByteData.sublistView(out);
  var prev = 0;
  for (var i = 44; i + 1 < wav.length; i += 2) {
    final s = inView.getInt16(i, Endian.little);
    outView.setUint16(i, (s - prev) & 0xFFFF, Endian.little);
    prev = s;
  }
  return out;
}

Uint8List _deltaDecode(Uint8List packed) {
  final out = Uint8List.fromList(packed);
  final inView = ByteData.sublistView(packed);
  final outView = ByteData.sublistView(out);
  var prev = 0;
  for (var i = 44; i + 1 < packed.length; i += 2) {
    final d = inView.getUint16(i, Endian.little);
    var s = (prev + d) & 0xFFFF;
    if (s >= 0x8000) s -= 0x10000; // back to signed
    outView.setInt16(i, s, Endian.little);
    prev = s;
  }
  return out;
}
