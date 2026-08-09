import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/adapters/audio/wav.dart';
import 'package:sleepytime/adapters/tts/tts_synthesizer.dart';

/// The parser has to walk the chunk list rather than assume a 44-byte header,
/// because a writer is free to slip a `LIST` or `fact` chunk in first and the
/// shortcut then reads metadata as audio — silently, as noise.
void main() {
  Uint8List pcm(int frames, {int channels = 1}) {
    final samples = Int16List(frames * channels);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (i * 137) % 30000 - 15000;
    }
    return Uint8List.sublistView(samples);
  }

  test('reads rate, channels and samples back out of a plain WAV', () {
    final audio = decodeWav(pcmToWav(pcm(1000), sampleRate: 24000));
    expect(audio.sampleRate, 24000);
    expect(audio.channels, 1);
    expect(audio.frames, 1000);
    expect(audio.duration.inMilliseconds, closeTo(41, 1));
  });

  test('samples survive the round trip byte for byte', () {
    final raw = pcm(64);
    final audio = decodeWav(pcmToWav(raw));
    expect(Uint8List.sublistView(audio.samples), raw);
  });

  test('stereo is kept interleaved', () {
    final audio = decodeWav(pcmToWav(pcm(500, channels: 2), channels: 2));
    expect(audio.channels, 2);
    expect(audio.frames, 500);
    expect(audio.samples.length, 1000);
  });

  test('a chunk between fmt and data is skipped, not read as audio', () {
    final plain = pcmToWav(pcm(100));
    // Splice a LIST chunk in ahead of `data`, which starts 36 bytes in.
    const dataAt = 36;
    final list = BytesBuilder()
      ..add('LIST'.codeUnits)
      ..add([8, 0, 0, 0])
      ..add('INFOxxxx'.codeUnits);
    final spliced = BytesBuilder()
      ..add(plain.sublist(0, dataAt))
      ..add(list.toBytes())
      ..add(plain.sublist(dataAt));

    final audio = decodeWav(spliced.toBytes());
    expect(audio.frames, 100);
    expect(Uint8List.sublistView(audio.samples), pcm(100));
  });

  test('an odd-length chunk is followed by a pad byte', () {
    final plain = pcmToWav(pcm(100));
    const dataAt = 36;
    final odd = BytesBuilder()
      ..add('note'.codeUnits)
      ..add([3, 0, 0, 0])
      ..add([1, 2, 3, 0]); // 3 bytes of payload, then the pad
    final spliced = BytesBuilder()
      ..add(plain.sublist(0, dataAt))
      ..add(odd.toBytes())
      ..add(plain.sublist(dataAt));

    expect(decodeWav(spliced.toBytes()).frames, 100);
  });

  test('a data size of 0xFFFFFFFF is clamped to what is there', () {
    final wav = pcmToWav(pcm(100));
    // The data chunk's length field sits at offset 40.
    ByteData.sublistView(wav).setUint32(40, 0xFFFFFFFF, Endian.little);
    expect(decodeWav(wav).frames, 100);
  });

  test('a half sample at the end is dropped rather than read', () {
    final wav = pcmToWav(pcm(100));
    expect(decodeWav(wav.sublist(0, wav.length - 1)).frames, 99);
  });

  group('rejects what it cannot convert, saying what it found', () {
    test('not a RIFF file', () {
      expect(
        () => decodeWav(Uint8List.fromList(List.filled(64, 0x41))),
        throwsA(isA<WavFormatException>()),
      );
    });

    test('8-bit samples', () {
      final wav = pcmToWav(pcm(100), bitsPerSample: 8);
      expect(
        () => decodeWav(wav),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.message,
            'message',
            contains('8-bit'),
          ),
        ),
      );
    });

    test('IEEE float', () {
      final wav = pcmToWav(pcm(100));
      ByteData.sublistView(wav).setUint16(20, 3, Endian.little);
      expect(
        () => decodeWav(wav),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.message,
            'message',
            contains('IEEE float'),
          ),
        ),
      );
    });

    test('no data chunk', () {
      expect(
        () => decodeWav(pcmToWav(Uint8List(0)).sublist(0, 36)),
        throwsA(isA<WavFormatException>()),
      );
    });
  });
}
