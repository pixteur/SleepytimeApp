/// Re-encoding narration into an MP3 a Lunii storyteller will play.
///
/// The device wants **MPEG-1 Layer III, 44.1 kHz, mono**, and that is not a
/// guess: `tool/lunii_audio_survey.dart` walked all 1,867,061 frames of the
/// 375 sounds across the nine packs on a physical FW2 device, and every single
/// frame is that — no exceptions, no ID3 anywhere, audio always starting at
/// byte 0. Those three are hard requirements.
///
/// **Bitrate is not.** The device's own content is VBR, spanning 32–320 kbps
/// and averaging 90. This encodes 128 kbps CBR instead, which is a choice
/// rather than a copy: constant bitrate is one less thing to go wrong on an
/// embedded decoder, and 128 kbps is squarely inside the range the device
/// already plays — 199,737 of its own frames are exactly that rate. It costs
/// size. A minute of narration is 960 kB against about 670 kB at the device's
/// own average, which against 7.4 GB of storage does not signify.
///
/// The leading Xing/LAME tag frame is kept, because every file on the device
/// has one. LAME writes the `Info` variant of it for constant bitrate.
///
/// Of the app's voices only ElevenLabs already conforms. Gemini and the
/// Windows voice hand back 24 kHz WAV, which is why this exists: LAME resamples
/// on the way through, so a 24 kHz mono capture goes in and a 44.1 kHz mono
/// stream comes out in one pass.
///
/// Not handled yet: **MP3 in**. OpenAI's voice returns 24 kHz MP3, which has to
/// be decoded before it can be re-encoded. The vendored DLL does export
/// mpglib's `hip_decode*`, so the way through is open — it is simply not built.
///
/// See [docs/lunii-sync.md](../../../docs/lunii-sync.md).
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'lame.dart';
import 'mp3_frame.dart';
import 'wav.dart';

/// Required by the device, measured across every frame on one.
const int luniiSampleRate = 44100;

/// Chosen, not required — see the note above on why constant bitrate.
const int luniiBitrateKbps = 128;

/// Input frames handed to LAME per call. Large enough that the per-call
/// overhead disappears, small enough that the scratch buffers stay modest.
const int _framesPerChunk = 8192;

/// `lame_encode_flush` documents 7200 bytes as enough for everything it can
/// emit; the encode buffer is never smaller than that so one size serves both.
const int _flushBufferSize = 7200;

/// True when this machine can encode at all. False on a platform with no
/// vendored LAME, where the caller should fall back to the STUdio zip export.
bool get canEncodeMp3 => Lame.instanceOrNull != null;

/// Convert a WAV — any sample rate, mono or stereo — into MP3 the storyteller
/// will play.
Uint8List wavToLuniiMp3(Uint8List wav) => encodePcmToLuniiMp3(decodeWav(wav));

/// As [wavToLuniiMp3], for already-decoded samples.
///
/// Throws [LameException] if the library is missing or the encode fails.
Uint8List encodePcmToLuniiMp3(WavAudio audio) {
  if (audio.frames == 0) {
    throw const LameException('Nothing to encode: the audio has no samples');
  }
  final lame = Lame.instance;
  final gfp = lame.init();
  if (gfp == nullptr) throw const LameException('lame_init returned null');

  // LAME resamples in → out, so the input rate is simply declared, not fixed
  // up beforehand. Channels in and mode out are separate settings: two in with
  // MONO out means LAME averages the pair down for us.
  lame.setInSampleRate(gfp, audio.sampleRate);
  lame.setNumChannels(gfp, audio.channels);
  lame.setOutSampleRate(gfp, luniiSampleRate);
  lame.setMode(gfp, LameMode.mono);
  lame.setBitrateKbps(gfp, luniiBitrateKbps);
  lame.setQuality(gfp, 2);
  // The device's own packs carry the tag, so write a real one — which obliges
  // the backfill after the flush below.
  lame.setWriteVbrTag(gfp, 1);
  // Nothing sets an ID3 field, but say so outright: the device wants none.
  lame.setWriteId3TagAutomatic(gfp, 0);

  if (lame.initParams(gfp) < 0) {
    lame.close(gfp);
    throw LameException(
      'LAME rejected ${audio.sampleRate} Hz / ${audio.channels}ch → '
      '$luniiSampleRate Hz mono at $luniiBitrateKbps kbps',
    );
  }

  // Resampling upward means more samples out than in, so the output buffer is
  // sized from the output rate — the usual "1.25 bytes per sample + 7200"
  // rule of thumb applied to what actually lands in it.
  final outFramesPerChunk =
      (_framesPerChunk * luniiSampleRate / audio.sampleRate).ceil();
  final mp3BufferSize = (outFramesPerChunk * 1.25).ceil() + _flushBufferSize;

  final pcmBuffer = calloc<Int16>(_framesPerChunk * audio.channels);
  final mp3Buffer = calloc<Uint8>(mp3BufferSize);
  final out = BytesBuilder(copy: false);

  try {
    final pcmView = pcmBuffer.asTypedList(_framesPerChunk * audio.channels);
    final mp3View = mp3Buffer.asTypedList(mp3BufferSize);

    for (var frame = 0; frame < audio.frames; frame += _framesPerChunk) {
      final frames = frame + _framesPerChunk <= audio.frames
          ? _framesPerChunk
          : audio.frames - frame;
      final count = frames * audio.channels;
      pcmView.setRange(0, count, audio.samples, frame * audio.channels);

      final written = audio.channels == 1
          // With one input channel LAME ignores the right pointer outright.
          ? lame.encodeBuffer(
              gfp,
              pcmBuffer,
              pcmBuffer,
              frames,
              mp3Buffer,
              mp3BufferSize,
            )
          : lame.encodeBufferInterleaved(
              gfp,
              pcmBuffer,
              frames,
              mp3Buffer,
              mp3BufferSize,
            );
      if (written < 0) {
        throw LameException(_encodeError('lame_encode_buffer', written));
      }
      out.add(Uint8List.fromList(mp3View.sublist(0, written)));
    }

    final flushed = lame.encodeFlush(gfp, mp3Buffer, mp3BufferSize);
    if (flushed < 0) {
      throw LameException(_encodeError('lame_encode_flush', flushed));
    }
    out.add(Uint8List.fromList(mp3View.sublist(0, flushed)));

    final mp3 = out.toBytes();
    _writeLametag(lame, gfp, mp3);
    _verify(mp3);
    return mp3;
  } finally {
    calloc.free(pcmBuffer);
    calloc.free(mp3Buffer);
    lame.close(gfp);
  }
}

/// Fill in the frame LAME reserved at the head of the stream.
///
/// With `bWriteVbrTag` on, LAME emits a blank frame first and leaves writing
/// the real Xing/LAME tag to the caller. Skipping this step is not a crash —
/// it is a file that starts with a frame of zeroes, which is exactly the kind
/// of thing that plays fine on a desktop and stutters on the device.
void _writeLametag(Lame lame, Pointer<Void> gfp, Uint8List mp3) {
  final scratch = calloc<Uint8>(_flushBufferSize);
  try {
    final size = lame.getLametagFrame(gfp, scratch, _flushBufferSize);
    // 0 means LAME decided against a tag; larger than the buffer means it
    // wanted more room than a frame can occupy. Neither should happen here.
    if (size == 0 || size > _flushBufferSize) return;
    if (size > mp3.length) {
      throw LameException(
        'LAME tag is $size bytes but the stream is only ${mp3.length}',
      );
    }
    mp3.setRange(0, size, scratch.asTypedList(size));
  } finally {
    calloc.free(scratch);
  }
}

/// Prove the bytes really are what the device expects, rather than trusting
/// that the settings above took effect.
void _verify(Uint8List mp3) {
  final header = Mp3FrameHeader.parse(mp3);
  if (header == null) {
    throw const LameException(
      'Encoded output does not start with an MP3 frame',
    );
  }
  if (header.version != MpegVersion.mpeg1 ||
      header.layer != 3 ||
      header.sampleRate != luniiSampleRate ||
      header.mode != ChannelMode.mono) {
    throw LameException(
      'Encoded ${header.summary}, but the storyteller needs '
      'MPEG1 L3 ${luniiSampleRate}Hz mono',
    );
  }
}

/// LAME's negative return codes, which are otherwise bare numbers.
String _encodeError(String call, int code) => switch (code) {
  -1 => '$call: output buffer too small',
  -2 => '$call: out of memory',
  -3 => '$call: encoder not initialised',
  -4 => '$call: psycho-acoustic problem',
  _ => '$call failed with $code',
};
