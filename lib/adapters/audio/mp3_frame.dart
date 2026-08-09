/// Reading an MPEG audio frame header.
///
/// A Lunii storyteller is fussy about what it will play — MPEG-1 Layer III,
/// 44.1 kHz, mono — and the only way to know a file qualifies is to decode its
/// first frame header. That makes this the check the encoder runs on its own
/// output, the assertion the tests make, and what
/// [tool/lunii_audio_survey.dart](../../../tool/lunii_audio_survey.dart) reads
/// off the device.
///
/// The header is four bytes of packed fields:
///
/// ```
/// AAAAAAAA AAABBCCD EEEEFFGH IIJJKLMM
/// ```
///
/// A sync, B version, C layer, D protection, E bitrate, F sample rate,
/// G padding, H private, I channel mode, J mode extension, K copyright,
/// L original, M emphasis.
library;

import 'dart:typed_data';

enum MpegVersion {
  mpeg1('MPEG1'),
  mpeg2('MPEG2'),
  mpeg25('MPEG2.5');

  const MpegVersion(this.label);
  final String label;
}

enum ChannelMode {
  stereo('stereo'),
  jointStereo('joint'),
  dualChannel('dual'),
  mono('mono');

  const ChannelMode(this.label);
  final String label;
}

/// Bitrates in kbps, indexed by the header's 4-bit bitrate field. Index 0 is
/// "free format" and 15 is invalid; both are treated as unparseable.
const List<int> _bitratesV1Layer3 = [
  0,
  32,
  40,
  48,
  56,
  64,
  80,
  96,
  112,
  128,
  160,
  192,
  224,
  256,
  320,
  0,
];
const List<int> _bitratesV2Layer3 = [
  0,
  8,
  16,
  24,
  32,
  40,
  48,
  56,
  64,
  80,
  96,
  112,
  128,
  144,
  160,
  0,
];

/// MPEG-1 sample rates; MPEG-2 halves these and MPEG-2.5 quarters them.
const List<int> _sampleRatesV1 = [44100, 48000, 32000, 0];

/// One decoded frame header.
class Mp3FrameHeader {
  const Mp3FrameHeader({
    required this.offset,
    required this.version,
    required this.layer,
    required this.sampleRate,
    required this.bitrateKbps,
    required this.mode,
    required this.padded,
  });

  /// Where in the buffer this frame starts. Anything other than 0 in a file
  /// we produced means stray bytes crept in ahead of the audio.
  final int offset;
  final MpegVersion version;

  /// 1, 2 or 3 — the Roman numeral in "Layer III".
  final int layer;
  final int sampleRate;
  final int bitrateKbps;
  final ChannelMode mode;
  final bool padded;

  int get channels => mode == ChannelMode.mono ? 1 : 2;

  /// Samples this frame carries, per channel.
  int get samplesPerFrame => layer == 1
      ? 384
      : (layer == 2 || version == MpegVersion.mpeg1)
      ? 1152
      : 576;

  /// Total size of the frame in bytes, header included.
  int get frameLength {
    if (layer == 1) {
      return (12 * bitrateKbps * 1000 ~/ sampleRate + (padded ? 1 : 0)) * 4;
    }
    final coefficient = version == MpegVersion.mpeg1 || layer == 2 ? 144 : 72;
    return coefficient * bitrateKbps * 1000 ~/ sampleRate + (padded ? 1 : 0);
  }

  String get summary =>
      '${version.label} L$layer ${sampleRate}Hz '
      '${bitrateKbps}kbps ${mode.label}';

  @override
  String toString() => 'Mp3FrameHeader($summary @$offset)';

  /// Decode the header at [offset], or null if there isn't a valid one exactly
  /// there. Free-format and reserved encodings count as invalid: they are
  /// legal MPEG but nothing this app should be producing or reading.
  static Mp3FrameHeader? parse(Uint8List bytes, [int offset = 0]) {
    if (offset < 0 || offset + 4 > bytes.length) return null;
    if (bytes[offset] != 0xFF || (bytes[offset + 1] & 0xE0) != 0xE0) {
      return null;
    }

    final versionBits = (bytes[offset + 1] >> 3) & 3;
    final layerBits = (bytes[offset + 1] >> 1) & 3;
    if (versionBits == 1 || layerBits == 0) return null; // reserved

    final bitrateIndex = (bytes[offset + 2] >> 4) & 0xF;
    final rateIndex = (bytes[offset + 2] >> 2) & 3;
    if (bitrateIndex == 0 || bitrateIndex == 0xF || rateIndex == 3) return null;

    final version = switch (versionBits) {
      3 => MpegVersion.mpeg1,
      2 => MpegVersion.mpeg2,
      _ => MpegVersion.mpeg25,
    };
    final divisor = switch (version) {
      MpegVersion.mpeg1 => 1,
      MpegVersion.mpeg2 => 2,
      MpegVersion.mpeg25 => 4,
    };
    final layer = 4 - layerBits;
    // The bitrate tables here only cover Layer III, which is all a storyteller
    // plays and all this app writes.
    if (layer != 3) return null;
    final bitrate = version == MpegVersion.mpeg1
        ? _bitratesV1Layer3[bitrateIndex]
        : _bitratesV2Layer3[bitrateIndex];

    return Mp3FrameHeader(
      offset: offset,
      version: version,
      layer: layer,
      sampleRate: _sampleRatesV1[rateIndex] ~/ divisor,
      bitrateKbps: bitrate,
      mode: ChannelMode.values[(bytes[offset + 3] >> 6) & 3],
      padded: (bytes[offset + 2] >> 1) & 1 == 1,
    );
  }

  /// Scan for the first frame header, skipping an ID3v2 tag if one is present.
  ///
  /// A lone sync pattern is easy to hit by chance inside audio data, so a
  /// candidate only counts if the frame it describes is followed by another
  /// valid header — unless it runs to the end of the buffer, which is the
  /// normal case when only a file's head is available.
  static Mp3FrameHeader? findFirst(Uint8List bytes) {
    var start = 0;
    if (bytes.length > 10 &&
        bytes[0] == 0x49 && // I
        bytes[1] == 0x44 && // D
        bytes[2] == 0x33) {
      // 3
      // Syncsafe 28-bit size — seven bits per byte — plus the 10-byte header.
      start =
          10 +
          ((bytes[6] & 0x7f) << 21 |
              (bytes[7] & 0x7f) << 14 |
              (bytes[8] & 0x7f) << 7 |
              (bytes[9] & 0x7f));
    }
    for (var i = start; i + 4 <= bytes.length; i++) {
      final header = parse(bytes, i);
      if (header == null) continue;
      final next = i + header.frameLength;
      if (next + 4 > bytes.length || parse(bytes, next) != null) return header;
    }
    return null;
  }
}
