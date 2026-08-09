/// Decoding MP3 back to samples, so it can be re-encoded for the device.
///
/// Two of the app's voices already return MP3 — ElevenLabs at 44.1 kHz, which
/// is what a storyteller plays, and OpenAI at 24 kHz, which is not. Until this
/// existed the OpenAI voice simply could not be sent: re-encoding needs the
/// audio back as samples first, and nothing could do that.
///
/// mpglib ships inside the same `libmp3lame.dll` the encoder uses, so this
/// costs no extra binary. See [lame.dart](lame.dart) for the bindings and
/// `windows/third_party/lame/README.md` for the library itself.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'lame.dart';
import 'wav.dart';

/// The most samples one call can hand back, per channel.
///
/// A frame is at most 1152 samples; mpglib's own examples use a buffer well
/// clear of that, and so does this — a decoder writing past the end of a
/// buffer is not something to be tight-fisted about.
const int _samplesPerCall = 1152 * 2;

/// How much MP3 to hand over at a time. Small enough that a broken stream
/// fails quickly, large enough not to make a syscall of every frame.
const int _inputChunk = 4096;

class Mp3DecodeException implements Exception {
  const Mp3DecodeException(this.message);
  final String message;

  @override
  String toString() => 'Mp3DecodeException: $message';
}

/// True when this machine can decode MP3 — the same library as [canEncodeMp3],
/// so in practice the two agree.
bool get canDecodeMp3 => Lame.instanceOrNull != null;

/// Decode [mp3] to samples.
///
/// Comes back interleaved when the source is stereo, matching [WavAudio]
/// everywhere else. Throws [Mp3DecodeException] on a stream mpglib rejects, or
/// one it decodes to nothing.
WavAudio decodeMp3(Uint8List mp3) {
  if (mp3.isEmpty) {
    throw const Mp3DecodeException('Nothing to decode');
  }
  final lame = Lame.instance;
  final hip = lame.hipInit();
  if (hip == nullptr) {
    throw const Mp3DecodeException('hip_decode_init returned null');
  }

  final input = calloc<Uint8>(_inputChunk);
  final left = calloc<Int16>(_samplesPerCall);
  final right = calloc<Int16>(_samplesPerCall);
  final info = calloc<Mp3Data>();
  final leftOut = BytesBuilder(copy: false);
  final rightOut = BytesBuilder(copy: false);

  try {
    final inputView = input.asTypedList(_inputChunk);
    var at = 0;
    var channels = 0;
    var sampleRate = 0;

    // Feed a chunk, drain everything it produced, repeat; then one last pass
    // with nothing to feed, because mpglib buffers internally and still has
    // frames to give after the final byte goes in.
    //
    // The draining pass is not optional even for a short clip. A file that
    // fits in one chunk produces nothing on the call that feeds it — mpglib is
    // still finding sync — and every sample it has comes out of the calls
    // afterwards.
    var feeding = true;
    while (feeding) {
      final remaining = mp3.length - at;
      final take = remaining <= 0
          ? 0
          : (remaining < _inputChunk ? remaining : _inputChunk);
      if (take > 0) {
        inputView.setRange(0, take, mp3, at);
        at += take;
      } else {
        feeding = false; // last time round: drain only
      }

      var samples = lame.hipDecodeHeaders(hip, input, take, left, right, info);
      while (samples != 0) {
        if (samples < 0) {
          throw Mp3DecodeException('mpglib rejected the stream ($samples)');
        }
        if (samples > _samplesPerCall) {
          throw Mp3DecodeException(
            'Decoder returned $samples samples for a $_samplesPerCall buffer',
          );
        }
        if (info.ref.headerParsed == 1) {
          channels = info.ref.stereo;
          sampleRate = info.ref.sampleRate;
        }
        leftOut.add(
          Uint8List.sublistView(Int16List.fromList(left.asTypedList(samples))),
        );
        if (channels > 1) {
          rightOut.add(
            Uint8List.sublistView(
              Int16List.fromList(right.asTypedList(samples)),
            ),
          );
        }
        // Zero-length input drains what is already buffered.
        samples = lame.hipDecodeHeaders(hip, input, 0, left, right, info);
      }
    }

    if (sampleRate <= 0 || leftOut.isEmpty) {
      throw const Mp3DecodeException('No decodable frames');
    }
    final leftSamples = Int16List.sublistView(leftOut.toBytes());
    if (channels <= 1) {
      return WavAudio(
        samples: leftSamples,
        sampleRate: sampleRate,
        channels: 1,
      );
    }
    final rightSamples = Int16List.sublistView(rightOut.toBytes());
    final frames = leftSamples.length < rightSamples.length
        ? leftSamples.length
        : rightSamples.length;
    final interleaved = Int16List(frames * 2);
    for (var i = 0; i < frames; i++) {
      interleaved[i * 2] = leftSamples[i];
      interleaved[i * 2 + 1] = rightSamples[i];
    }
    return WavAudio(samples: interleaved, sampleRate: sampleRate, channels: 2);
  } finally {
    calloc.free(input);
    calloc.free(left);
    calloc.free(right);
    calloc.free(info);
    lame.hipExit(hip);
  }
}
