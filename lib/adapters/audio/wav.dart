/// Just enough WAV to hand a voice's output to an encoder.
///
/// A WAV file is a RIFF container: a 12-byte header, then a run of chunks that
/// each carry a four-character id, a little-endian length, and that many bytes
/// of payload, padded to an even boundary. The two that matter are `fmt ` and
/// `data`. Walking the chunks properly is the point of this file — the
/// familiar "skip 44 bytes" shortcut is wrong the moment a writer inserts a
/// `LIST` or `fact` chunk, and it fails silently, as noise.
///
/// Only 16-bit PCM is decoded, because that is what every voice in this app
/// produces — Gemini's raw PCM wrapped by `pcmToWav`, and the Windows system
/// voice. Anything else throws [WavFormatException] naming what it found
/// rather than being converted approximately.
library;

import 'dart:typed_data';

/// Interleaved 16-bit PCM, ready to encode.
class WavAudio {
  const WavAudio({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });

  /// Interleaved across [channels]: for stereo, L R L R ….
  final Int16List samples;
  final int sampleRate;
  final int channels;

  /// Sample frames — one per instant of time, whatever the channel count.
  int get frames => samples.length ~/ channels;

  Duration get duration =>
      Duration(microseconds: frames * 1000000 ~/ sampleRate);
}

class WavFormatException implements Exception {
  const WavFormatException(this.message);
  final String message;

  @override
  String toString() => 'WavFormatException: $message';
}

const int _formatPcm = 1;
const int _formatExtensible = 0xFFFE;

/// Read [bytes] as a WAV file.
WavAudio decodeWav(Uint8List bytes) {
  if (bytes.length < 12) {
    throw WavFormatException('Too short to be a WAV: ${bytes.length} bytes');
  }
  final view = ByteData.sublistView(bytes);
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
    throw WavFormatException(
      'Not a WAV: expected RIFF/WAVE, found '
      '"${_tag(bytes, 0)}"/"${_tag(bytes, 8)}"',
    );
  }

  int? sampleRate;
  int? channels;
  int? bitsPerSample;
  int? format;
  Uint8List? data;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    final declared = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    // A truncated final chunk — or the 0xFFFFFFFF some streaming writers
    // emit — is clamped to what is actually there rather than throwing.
    final size = declared > bytes.length - body
        ? bytes.length - body
        : declared;

    if (id == 'fmt ') {
      if (size < 16) {
        throw WavFormatException('fmt chunk is $size bytes, needs 16');
      }
      format = view.getUint16(body, Endian.little);
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      bitsPerSample = view.getUint16(body + 14, Endian.little);
      // WAVE_FORMAT_EXTENSIBLE hides the real format in the first two bytes of
      // a 16-byte SubFormat GUID at the end of a 40-byte fmt chunk.
      if (format == _formatExtensible && size >= 40) {
        format = view.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      data = Uint8List.sublistView(bytes, body, body + size);
    }
    // Chunks are word-aligned: an odd length is followed by a pad byte.
    offset = body + size + (size.isOdd ? 1 : 0);
  }

  if (sampleRate == null || channels == null || bitsPerSample == null) {
    throw const WavFormatException('No fmt chunk');
  }
  if (data == null) throw const WavFormatException('No data chunk');
  if (format != _formatPcm) {
    throw WavFormatException(
      'Only PCM is supported, found format $format '
      '(${format == 3 ? 'IEEE float' : 'unknown'})',
    );
  }
  if (bitsPerSample != 16) {
    throw WavFormatException(
      'Only 16-bit samples are supported, found $bitsPerSample-bit',
    );
  }
  if (channels < 1 || channels > 2) {
    throw WavFormatException('Expected 1 or 2 channels, found $channels');
  }
  if (sampleRate <= 0) {
    throw WavFormatException('Nonsense sample rate: $sampleRate');
  }

  // A partial frame at the end is dropped: half a sample is not audio.
  final frames = data.length ~/ (2 * channels);
  final samples = Int16List(frames * channels);
  final source = ByteData.sublistView(data);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = source.getInt16(i * 2, Endian.little);
  }
  return WavAudio(samples: samples, sampleRate: sampleRate, channels: channels);
}

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes, offset, offset + 4);
